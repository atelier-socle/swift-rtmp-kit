// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// Shared test configuration with very short stability duration for fast tests
private func testPolicy() -> AdaptiveBitratePolicy {
    .custom(
        AdaptiveBitrateConfiguration(
            minBitrate: 500_000,
            maxBitrate: 6_000_000,
            stepDown: 0.75,
            stepUp: 1.10,
            downTriggerThreshold: 0.25,
            upStabilityDuration: 0.01,
            measurementWindow: 3.0,
            dropRateTriggerThreshold: 0.02
        )
    )
}

@Suite("NetworkConditionMonitor — Lifecycle and State")
struct NetworkConditionMonitorLifecycleTests {

    private let defaultBitrate = 3_000_000

    @Test("Initial state has correct bitrate and nil snapshot")
    func initialState() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        let bitrate = await monitor.currentBitrate
        let snapshot = await monitor.currentSnapshot
        #expect(bitrate == defaultBitrate)
        #expect(snapshot == nil)
    }

    @Test("Start then stop finishes recommendations stream")
    func startStopLifecycle() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        await monitor.start()
        await monitor.stop()
        let recs = await monitor.emittedRecommendations
        #expect(recs.isEmpty)
    }

    @Test("No recommendations when policy is disabled")
    func disabledPolicyNoRecommendations() async {
        let monitor = NetworkConditionMonitor(policy: .disabled, initialBitrate: defaultBitrate)
        await monitor.start()

        for _ in 0..<20 {
            await monitor.recordRTT(0.05)
        }
        await monitor.recordRTT(0.50)
        await monitor.recordBytesSent(1_000_000, pendingBytes: 10_000_000)

        let recs = await monitor.emittedRecommendations
        #expect(recs.isEmpty)
    }

    @Test("Reset clears state to initial values")
    func resetClearsState() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        await monitor.start()

        await monitor.recordBytesSent(100_000, pendingBytes: 500)
        await monitor.recordRTT(0.05)

        let snapshotBefore = await monitor.currentSnapshot
        #expect(snapshotBefore != nil)

        await monitor.reset()

        let bitrateAfter = await monitor.currentBitrate
        let snapshotAfter = await monitor.currentSnapshot
        #expect(bitrateAfter == defaultBitrate)
        #expect(snapshotAfter == nil)

        let recs = await monitor.emittedRecommendations
        #expect(recs.isEmpty)
    }

    @Test("ForceRecommendation emits immediately with manual reason")
    func forceRecommendation() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        await monitor.start()

        await monitor.forceRecommendation(bitrate: 1_000_000)

        let bitrate = await monitor.currentBitrate
        #expect(bitrate == 1_000_000)

        let recs = await monitor.emittedRecommendations
        #expect(recs.count == 1)
        #expect(recs.first?.reason == .manual)
        #expect(recs.first?.recommendedBitrate == 1_000_000)
        #expect(recs.first?.previousBitrate == defaultBitrate)
    }

    @Test("Policy update to disabled stops recommendations")
    func policyUpdateToDisabled() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        await monitor.start()

        for _ in 0..<5 {
            await monitor.recordRTT(0.05)
        }

        await monitor.setPolicy(.disabled)
        await monitor.recordRTT(0.50)
        await monitor.recordBytesSent(1, pendingBytes: 50_000_000)

        let recs = await monitor.emittedRecommendations
        #expect(recs.isEmpty)
    }

    @Test("NetworkSnapshot fields are populated after measurements")
    func snapshotFields() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        await monitor.start()

        await monitor.recordBytesSent(50_000, pendingBytes: 1024)
        await monitor.recordRTT(0.05)
        await monitor.recordDroppedFrame()
        await monitor.recordSentFrame()

        let snapshot = await monitor.currentSnapshot
        #expect(snapshot != nil)
        #expect(snapshot?.pendingBytes == 1024)
        #expect(snapshot?.roundTripTime == 0.05)
        #expect(snapshot?.timestamp ?? 0 > 0)
    }
}

@Suite("NetworkConditionMonitor — Step-Down Triggers")
struct NetworkConditionMonitorStepDownTests {

    private let defaultBitrate = 3_000_000

    @Test("RTT spike triggers step-down recommendation")
    func rttSpikeTrigger() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        await monitor.start()

        // Establish baseline (upStabilityDuration = 0.01s)
        for _ in 0..<5 {
            await monitor.recordRTT(0.05)
        }

        // Small wait for baseline establishment timing
        try? await Task.sleep(for: .milliseconds(15))

        // RTT spike: 0.10 is 100% increase > 25% threshold
        await monitor.recordRTT(0.10)

        let recs = await monitor.emittedRecommendations
        let stepDown = recs.first { $0.reason == .rttSpike }
        #expect(stepDown != nil)
        #expect((stepDown?.recommendedBitrate ?? defaultBitrate) < defaultBitrate)
    }

    @Test("Congestion via pending bytes triggers step-down")
    func congestionTrigger() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        await monitor.start()

        // pendingThreshold = 3M * 3 / 8 = 1_125_000; inject 5M >> threshold
        await monitor.recordBytesSent(1, pendingBytes: 5_000_000)

        let recs = await monitor.emittedRecommendations
        let congestion = recs.first { $0.reason == .congestionDetected }
        #expect(congestion != nil)
    }

    @Test("Drop rate exceeding threshold triggers step-down")
    func dropRateTrigger() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        await monitor.start()

        // 95 sent + 5 dropped = 5% > 2% threshold
        for _ in 0..<95 {
            await monitor.recordSentFrame()
        }
        for _ in 0..<5 {
            await monitor.recordDroppedFrame()
        }

        let recs = await monitor.emittedRecommendations
        let dropRate = recs.first { $0.reason == .dropRateExceeded }
        #expect(dropRate != nil)
    }

    @Test("Step-down respects minBitrate floor")
    func stepDownRespectsMinBitrate() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: 500_000)
        await monitor.start()

        await monitor.recordBytesSent(1, pendingBytes: 5_000_000)

        let recs = await monitor.emittedRecommendations
        for rec in recs where rec.reason != .manual {
            #expect(rec.recommendedBitrate >= 500_000)
        }
    }

    @Test("Cooldown suppresses rapid oscillation")
    func cooldownSuppressesOscillation() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: defaultBitrate)
        await monitor.start()

        // Three rapid congestion events — only first should trigger
        await monitor.recordBytesSent(1, pendingBytes: 5_000_000)
        await monitor.recordBytesSent(1, pendingBytes: 5_000_000)
        await monitor.recordBytesSent(1, pendingBytes: 5_000_000)

        let recs = await monitor.emittedRecommendations
        let congestionRecs = recs.filter { $0.reason == .congestionDetected }
        #expect(congestionRecs.count == 1)
    }
}

@Suite("NetworkConditionMonitor — Step-Up Triggers")
struct NetworkConditionMonitorStepUpTests {

    @Test("Stable conditions trigger step-up")
    func stableConditionsStepUp() async {
        let initialBitrate = 2_000_000
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: initialBitrate)
        await monitor.start()

        try? await Task.sleep(for: .milliseconds(15))

        // EWMA bandwidth must converge above currentBitrate * 1.15 = 2_300_000
        // bytesSent * 8 = 500_000 * 8 = 4_000_000 bits — well above threshold
        for _ in 0..<50 {
            await monitor.recordBytesSent(500_000, pendingBytes: 0)
        }

        let recs = await monitor.emittedRecommendations
        let stepUp = recs.first { $0.reason == .bandwidthRecovered }
        #expect(stepUp != nil)
        #expect((stepUp?.recommendedBitrate ?? 0) > initialBitrate)
    }

    @Test("Step-up respects maxBitrate ceiling")
    func stepUpRespectsMaxBitrate() async {
        let monitor = NetworkConditionMonitor(policy: testPolicy(), initialBitrate: 6_000_000)
        await monitor.start()

        try? await Task.sleep(for: .milliseconds(15))

        for _ in 0..<50 {
            await monitor.recordBytesSent(5_000_000, pendingBytes: 0)
        }

        let recs = await monitor.emittedRecommendations
        let stepUps = recs.filter { $0.reason == .bandwidthRecovered }
        #expect(stepUps.isEmpty)
    }
}
