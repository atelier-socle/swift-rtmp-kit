// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Test Helpers

/// Build a scripted server response sequence for a successful publish.
private func makePublishScript(streamID: Double = 1) -> [RTMPMessage] {
    [
        RTMPMessage(
            command: .result(
                transactionID: 1,
                properties: nil,
                information: .object([
                    ("code", .string("NetConnection.Connect.Success"))
                ])
            )),
        RTMPMessage(
            command: .result(
                transactionID: 4,
                properties: nil,
                information: .number(streamID)
            )),
        RTMPMessage(
            command: .onStatus(
                information: .object([
                    ("code", .string("NetStream.Publish.Start")),
                    ("description", .string("Publishing"))
                ])))
    ]
}

// MARK: - Suite 1: Policies and Configuration

@Suite("Adaptive Bitrate Showcase — Policies and Configuration")
struct ABRPoliciesShowcaseTests {

    @Test("Conservative policy for live events and podcasts")
    func conservativePolicy() {
        let policy = AdaptiveBitratePolicy.conservative(min: 500_000, max: 4_000_000)
        let config = policy.configuration
        #expect(config != nil)
        #expect(config?.minBitrate == 500_000)
        #expect(config?.maxBitrate == 4_000_000)
        #expect(config?.stepDown == 0.80)
        #expect(config?.upStabilityDuration == 20.0)
    }

    @Test("Responsive policy for gaming and sport")
    func responsivePolicy() {
        let policy = AdaptiveBitratePolicy.responsive(min: 1_000_000, max: 6_000_000)
        let config = policy.configuration
        #expect(config?.stepDown == 0.75)
        #expect(config?.stepUp == 1.10)
        #expect(config?.measurementWindow == 3.0)
    }

    @Test("Aggressive policy for casual streaming")
    func aggressivePolicy() {
        let policy = AdaptiveBitratePolicy.aggressive(min: 300_000, max: 3_000_000)
        let config = policy.configuration
        #expect(config?.stepDown == 0.65)
        #expect(config?.stepUp == 1.15)
        #expect(config?.downTriggerThreshold == 0.15)
    }

    @Test("Disabled policy has no configuration")
    func disabledPolicy() {
        #expect(AdaptiveBitratePolicy.disabled.configuration == nil)
    }

    @Test("Custom policy with full control")
    func customPolicy() {
        let customConfig = AdaptiveBitrateConfiguration(
            minBitrate: 200_000,
            maxBitrate: 8_000_000,
            stepDown: 0.70,
            stepUp: 1.20,
            downTriggerThreshold: 0.30,
            upStabilityDuration: 12.0,
            measurementWindow: 4.0,
            dropRateTriggerThreshold: 0.04
        )
        let policy = AdaptiveBitratePolicy.custom(customConfig)
        #expect(policy.configuration == customConfig)
    }

    @Test("ABR configuration in RTMPConfiguration — default is disabled")
    func defaultConfigDisabled() {
        let config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
        #expect(config.adaptiveBitrate == .disabled)
        #expect(config.frameDroppingStrategy == .default)
    }

    @Test("RTMPConfiguration with responsive ABR for Twitch")
    func twitchWithResponsiveABR() {
        var config = RTMPConfiguration.twitch(streamKey: "live_abc123")
        config.adaptiveBitrate = .responsive(min: 1_000_000, max: 6_000_000)
        #expect(config.adaptiveBitrate.configuration != nil)
        #expect(config.url.contains("twitch"))
    }

    @Test("RTMPConfiguration with custom frame dropping strategy")
    func customFrameDroppingStrategy() {
        var config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
        config.frameDroppingStrategy = .aggressive
        #expect(config.frameDroppingStrategy.maxConsecutiveNonKeyframeDrops == 60)
    }
}

// MARK: - Suite 2: NetworkConditionMonitor standalone

@Suite("Adaptive Bitrate Showcase — Monitor Standalone")
struct ABRMonitorShowcaseTests {

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

    @Test("Monitor emits step-down recommendation on RTT spike")
    func rttSpikeStepDown() async {
        let monitor = NetworkConditionMonitor(
            policy: testPolicy(), initialBitrate: 3_000_000
        )
        await monitor.start()

        for _ in 0..<15 {
            await monitor.recordRTT(0.05)
        }
        try? await Task.sleep(for: .milliseconds(15))
        await monitor.recordRTT(0.12)

        let recs = await monitor.emittedRecommendations
        let stepDown = recs.first { $0.reason == .rttSpike }
        #expect(stepDown != nil)
        #expect((stepDown?.recommendedBitrate ?? 3_000_000) < 3_000_000)
    }

    @Test("Monitor emits step-down on congestion (buffer saturation)")
    func congestionStepDown() async {
        let monitor = NetworkConditionMonitor(
            policy: testPolicy(), initialBitrate: 3_000_000
        )
        await monitor.start()
        await monitor.recordBytesSent(1, pendingBytes: 10_000_000)

        let recs = await monitor.emittedRecommendations
        #expect(recs.first { $0.reason == .congestionDetected } != nil)
    }

    @Test("Monitor emits step-down on excessive frame drop rate")
    func dropRateStepDown() async {
        let monitor = NetworkConditionMonitor(
            policy: testPolicy(), initialBitrate: 3_000_000
        )
        await monitor.start()

        for _ in 0..<100 { await monitor.recordSentFrame() }
        for _ in 0..<5 { await monitor.recordDroppedFrame() }

        let recs = await monitor.emittedRecommendations
        #expect(recs.first { $0.reason == .dropRateExceeded } != nil)
    }

    @Test("Monitor emits step-up after sustained stability")
    func stabilityStepUp() async {
        let aggressivePolicy = AdaptiveBitratePolicy.custom(
            AdaptiveBitrateConfiguration(
                minBitrate: 500_000,
                maxBitrate: 6_000_000,
                stepDown: 0.65,
                stepUp: 1.15,
                downTriggerThreshold: 0.15,
                upStabilityDuration: 0.01,
                measurementWindow: 2.0,
                dropRateTriggerThreshold: 0.01
            )
        )
        let monitor = NetworkConditionMonitor(
            policy: aggressivePolicy, initialBitrate: 2_000_000
        )
        await monitor.start()

        for _ in 0..<10 { await monitor.recordRTT(0.03) }
        try? await Task.sleep(for: .milliseconds(15))
        for _ in 0..<50 {
            await monitor.recordBytesSent(500_000, pendingBytes: 0)
        }

        let recs = await monitor.emittedRecommendations
        let stepUp = recs.first { $0.reason == .bandwidthRecovered }
        #expect(stepUp != nil)
        #expect((stepUp?.recommendedBitrate ?? 0) > 2_000_000)
    }

    @Test("Recommended bitrate never exceeds maxBitrate")
    func neverExceedsMax() async {
        let monitor = NetworkConditionMonitor(
            policy: testPolicy(), initialBitrate: 6_000_000
        )
        await monitor.start()
        try? await Task.sleep(for: .milliseconds(15))

        for _ in 0..<50 {
            await monitor.recordBytesSent(5_000_000, pendingBytes: 0)
        }

        let recs = await monitor.emittedRecommendations
        let stepUps = recs.filter { $0.reason == .bandwidthRecovered }
        #expect(stepUps.isEmpty)
    }

    @Test("Recommended bitrate never falls below minBitrate")
    func neverBelowMin() async {
        let monitor = NetworkConditionMonitor(
            policy: testPolicy(), initialBitrate: 500_000
        )
        await monitor.start()
        await monitor.recordBytesSent(1, pendingBytes: 50_000_000)

        let recs = await monitor.emittedRecommendations
        for rec in recs where rec.reason != .manual {
            #expect(rec.recommendedBitrate >= 500_000)
        }
    }

    @Test("forceRecommendation overrides monitor with manual reason")
    func forceOverride() async {
        let monitor = NetworkConditionMonitor(
            policy: testPolicy(), initialBitrate: 3_000_000
        )
        await monitor.start()
        await monitor.forceRecommendation(bitrate: 1_500_000)

        let recs = await monitor.emittedRecommendations
        #expect(recs.count == 1)
        #expect(recs.first?.reason == .manual)
        #expect(recs.first?.recommendedBitrate == 1_500_000)
    }

    @Test("Cooldown prevents bitrate oscillation")
    func cooldownPreventsOscillation() async {
        let monitor = NetworkConditionMonitor(
            policy: testPolicy(), initialBitrate: 3_000_000
        )
        await monitor.start()

        await monitor.recordBytesSent(1, pendingBytes: 10_000_000)
        await monitor.recordBytesSent(1, pendingBytes: 10_000_000)
        await monitor.recordBytesSent(1, pendingBytes: 10_000_000)

        let recs = await monitor.emittedRecommendations
        let congestionRecs = recs.filter { $0.reason == .congestionDetected }
        #expect(congestionRecs.count == 1)
    }

    @Test("NetworkSnapshot captures all network metrics")
    func snapshotCaptures() async {
        let monitor = NetworkConditionMonitor(
            policy: testPolicy(), initialBitrate: 3_000_000
        )
        await monitor.start()
        await monitor.recordRTT(0.04)
        await monitor.recordBytesSent(10_000, pendingBytes: 500)

        let snapshot = await monitor.currentSnapshot
        #expect(snapshot != nil)
        #expect(snapshot?.roundTripTime == 0.04)
        #expect(snapshot?.pendingBytes == 500)
        #expect(snapshot?.dropRate == 0.0)
    }

    @Test("Monitor reset clears all state")
    func resetClears() async {
        let monitor = NetworkConditionMonitor(
            policy: testPolicy(), initialBitrate: 3_000_000
        )
        await monitor.start()
        await monitor.recordRTT(0.05)
        await monitor.recordBytesSent(50_000, pendingBytes: 1000)
        await monitor.reset()

        let snapshot = await monitor.currentSnapshot
        let bitrate = await monitor.currentBitrate
        #expect(snapshot == nil)
        #expect(bitrate == 3_000_000)
    }
}

// MARK: - Suite 3: Frame Dropping Strategy

@Suite("Adaptive Bitrate Showcase — Frame Dropping")
struct ABRFrameDroppingShowcaseTests {

    @Test("B-frames are dropped first under congestion")
    func bFramesDroppedFirst() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            strategy.shouldDrop(priority: .bFrame, consecutiveDropCount: 0, congestionLevel: 0.5)
        )
    }

    @Test("I-frames (keyframes) are never dropped")
    func iFramesNeverDropped() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            !strategy.shouldDrop(priority: .iFrame, consecutiveDropCount: 0, congestionLevel: 1.0)
        )
    }

    @Test("P-frames are preserved under mild congestion")
    func pFramesPreservedMild() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            !strategy.shouldDrop(priority: .pFrame, consecutiveDropCount: 0, congestionLevel: 0.4)
        )
    }

    @Test("P-frames are dropped under severe congestion")
    func pFramesDroppedSevere() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            strategy.shouldDrop(priority: .pFrame, consecutiveDropCount: 0, congestionLevel: 0.8)
        )
    }

    @Test("Max consecutive drops prevents all non-keyframe drops (GOP recovery)")
    func maxDropsGOPRecovery() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            !strategy.shouldDrop(priority: .pFrame, consecutiveDropCount: 30, congestionLevel: 1.0)
        )
        #expect(
            !strategy.shouldDrop(priority: .bFrame, consecutiveDropCount: 30, congestionLevel: 1.0)
        )
    }

    @Test("Keyframe request issued after max consecutive drops")
    func keyframeRequestAfterMaxDrops() {
        let strategy = FrameDroppingStrategy.default
        #expect(strategy.shouldRequestKeyframe(consecutiveDropCount: 30))
        #expect(!strategy.shouldRequestKeyframe(consecutiveDropCount: 29))
    }

    @Test("Conservative strategy has lower drop threshold")
    func conservativeLowerThreshold() {
        let strategy = FrameDroppingStrategy.conservative
        #expect(strategy.maxConsecutiveNonKeyframeDrops == 10)
        #expect(strategy.shouldRequestKeyframe(consecutiveDropCount: 10))
    }
}

// MARK: - Suite 4: RTMPPublisher ABR Integration

@Suite("Adaptive Bitrate Showcase — Publisher Integration")
struct ABRPublisherShowcaseTests {

    @Test("Publisher with disabled ABR has no monitor")
    func disabledABRNoMonitor() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        try await publisher.publish(
            configuration: RTMPConfiguration(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
        )

        let bitrate = await publisher.currentVideoBitrate
        #expect(bitrate == 3_000_000)

        await publisher.disconnect()
    }

    @Test("Publisher exposes currentVideoBitrate")
    func exposesCurrentBitrate() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let bitrate = await publisher.currentVideoBitrate
        #expect(bitrate == 3_000_000)
    }

    @Test("Publisher with responsive ABR starts monitor on connect")
    func responsiveABRStartsMonitor() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        var config = RTMPConfiguration(url: "rtmp://localhost/app", streamKey: "test")
        config.adaptiveBitrate = .responsive(min: 500_000, max: 6_000_000)
        try await publisher.publish(configuration: config)

        // Send frames — no crash
        try await publisher.sendVideo([0x01, 0x02], timestamp: 0, isKeyframe: true)
        try await publisher.sendAudio([0xAA, 0xBB], timestamp: 0)

        await publisher.disconnect()
    }

    @Test("bitrateRecommendation event forwarded on stream")
    func bitrateRecommendationForwarded() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        var config = RTMPConfiguration(url: "rtmp://localhost/app", streamKey: "test")
        config.adaptiveBitrate = .responsive(min: 500_000, max: 6_000_000)
        try await publisher.publish(configuration: config)

        // Collect events in background
        let eventStream = await publisher.events
        let eventTask = Task {
            var collected: [RTMPEvent] = []
            for await event in eventStream {
                collected.append(event)
                if case .bitrateRecommendation = event { break }
            }
            return collected
        }

        await publisher.forceVideoBitrate(1_500_000)

        // Wait briefly for event propagation
        try await Task.sleep(for: .milliseconds(50))
        eventTask.cancel()

        let bitrate = await publisher.currentVideoBitrate
        #expect(bitrate == 1_500_000)

        await publisher.disconnect()
    }

    @Test("forceVideoBitrate updates currentVideoBitrate")
    func forceUpdatesBitrate() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        var config = RTMPConfiguration(url: "rtmp://localhost/app", streamKey: "test")
        config.adaptiveBitrate = .responsive(min: 500_000, max: 6_000_000)
        try await publisher.publish(configuration: config)

        await publisher.forceVideoBitrate(1_200_000)
        let bitrate = await publisher.currentVideoBitrate
        #expect(bitrate == 1_200_000)

        await publisher.disconnect()
    }

    @Test("forceVideoBitrate is no-op when ABR disabled")
    func forceNoOpWhenDisabled() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        try await publisher.publish(
            configuration: RTMPConfiguration(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
        )

        await publisher.forceVideoBitrate(1_200_000)
        let bitrate = await publisher.currentVideoBitrate
        #expect(bitrate == 3_000_000)

        await publisher.disconnect()
    }

    @Test("Frame dropping: keyframes always pass through")
    func keyframesAlwaysPassThrough() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        var config = RTMPConfiguration(url: "rtmp://localhost/app", streamKey: "test")
        config.adaptiveBitrate = .responsive(min: 500_000, max: 6_000_000)
        try await publisher.publish(configuration: config)

        // Simulate congestion via ABR monitor
        let abrMon = await publisher.abrMonitor
        await abrMon?.recordBytesSent(1, pendingBytes: 50_000_000)

        let sentBefore = await mock.sentBytes.count
        try await publisher.sendVideo([0x01], timestamp: 0, isKeyframe: true)
        let sentAfter = await mock.sentBytes.count

        // Keyframe was sent (sentBytes grew)
        #expect(sentAfter > sentBefore)

        await publisher.disconnect()
    }

    @Test("Frame dropping: non-keyframes dropped under congestion")
    func nonKeyframesDroppedUnderCongestion() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        var config = RTMPConfiguration(url: "rtmp://localhost/app", streamKey: "test")
        config.adaptiveBitrate = .responsive(min: 500_000, max: 6_000_000)
        try await publisher.publish(configuration: config)

        // Simulate severe congestion
        let abrMon = await publisher.abrMonitor
        await abrMon?.recordBytesSent(1, pendingBytes: 50_000_000)

        let sentBefore = await mock.sentBytes.count
        try await publisher.sendVideo([0x01], timestamp: 0, isKeyframe: false)
        let sentAfter = await mock.sentBytes.count

        // Non-keyframe was dropped (sentBytes unchanged)
        #expect(sentAfter == sentBefore)

        let stats = await publisher.statistics
        #expect(stats.droppedFrames > 0)

        await publisher.disconnect()
    }

    @Test("ABR monitor stops cleanly on disconnect")
    func abrStopsOnDisconnect() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        var config = RTMPConfiguration(url: "rtmp://localhost/app", streamKey: "test")
        config.adaptiveBitrate = .responsive(min: 500_000, max: 6_000_000)
        try await publisher.publish(configuration: config)

        await publisher.disconnect()
        // No crash, monitor is nil
        let abrMon = await publisher.abrMonitor
        #expect(abrMon == nil)
    }

    @Test("ABR resets on reconnect")
    func abrResetsOnReconnect() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        var config = RTMPConfiguration(url: "rtmp://localhost/app", streamKey: "test")
        config.adaptiveBitrate = .responsive(min: 500_000, max: 6_000_000)
        try await publisher.publish(configuration: config)

        await publisher.forceVideoBitrate(1_000_000)
        let bitrateModified = await publisher.currentVideoBitrate
        #expect(bitrateModified == 1_000_000)

        await publisher.disconnect()

        // After disconnect, bitrate resets
        let bitrateReset = await publisher.currentVideoBitrate
        #expect(bitrateReset == 3_000_000)
    }
}
