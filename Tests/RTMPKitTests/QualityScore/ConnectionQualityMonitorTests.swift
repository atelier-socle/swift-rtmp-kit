// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ConnectionQualityMonitor")
struct ConnectionQualityMonitorTests {

    @Test("after start, scores stream emits values")
    func scoresEmitAfterStart() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordRTT(10.0)
        await monitor.recordBytesSent(500_000, targetBitrate: 4_000_000)

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        #expect(score != nil)
        #expect(score?.overall ?? 0 > 0.0)
        #expect(score?.overall ?? 2 <= 1.0)

        _ = await monitor.stop()
    }

    @Test("recordRTT(0) → latency score approaches 1.0")
    func zeroRTTHighLatency() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordRTT(0.0)

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        let latency = score?.score(for: .latency) ?? 0
        #expect(latency >= 0.95)

        _ = await monitor.stop()
    }

    @Test("recordRTT(200) → latency score approaches 0.0")
    func highRTTLowLatency() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordRTT(200.0)

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        let latency = score?.score(for: .latency) ?? 1
        #expect(latency <= 0.05)

        _ = await monitor.stop()
    }

    @Test("recordBytesSent at 100% of target → throughput ≈ 1.0")
    func fullThroughput() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        // Sending 500KB at 4Mbps target: 500000*8 = 4Mbps per sample
        await monitor.recordBytesSent(500_000, targetBitrate: 4_000_000)

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        let throughput = score?.score(for: .throughput) ?? 0
        #expect(throughput >= 0.9)

        _ = await monitor.stop()
    }

    @Test("recordBytesSent at 50% of target → throughput ≈ 0.5")
    func halfThroughput() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordBytesSent(250_000, targetBitrate: 4_000_000)

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        let throughput = score?.score(for: .throughput) ?? 0
        #expect(throughput >= 0.4)
        #expect(throughput <= 0.6)

        _ = await monitor.stop()
    }

    @Test("recordFrameDrop × 3 → frameDropRate score < 1.0")
    func frameDropsReduceScore() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        for _ in 0..<100 { await monitor.recordSentFrame() }
        for _ in 0..<3 { await monitor.recordFrameDrop() }

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        let dropScore = score?.score(for: .frameDropRate) ?? 1
        #expect(dropScore < 1.0)

        _ = await monitor.stop()
    }

    @Test("recordReconnection × 3 → stability score = 0.0")
    func reconnectsReduceStability() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        for _ in 0..<3 { await monitor.recordReconnection() }

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        let stability = score?.score(for: .stability) ?? 1
        #expect(stability <= 0.01)

        _ = await monitor.stop()
    }

    @Test("recordBitrateAchievement actual == configured → score 1.0")
    func fullBitrateAchievement() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordBitrateAchievement(
            actual: 4_000_000, configured: 4_000_000
        )

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        let achievement = score?.score(for: .bitrateAchievement) ?? 0
        #expect(achievement >= 0.99)

        _ = await monitor.stop()
    }

    @Test("currentScore is nil before first scoring interval")
    func currentScoreNilInitially() async {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 1.0, reportingWindow: 30.0
        )
        let score = await monitor.currentScore
        #expect(score == nil)
    }

    @Test("generateReport returns report with samples")
    func generateReportHasSamples() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordRTT(10.0)

        var iterator = await monitor.scores.makeAsyncIterator()
        _ = await iterator.next()

        let report = await monitor.generateReport()
        #expect(report != nil)
        #expect((report?.samples.count ?? 0) >= 1)

        _ = await monitor.stop()
    }

    @Test("stop returns non-nil report after scoring started")
    func stopReturnsReport() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordRTT(10.0)

        var iterator = await monitor.scores.makeAsyncIterator()
        _ = await iterator.next()

        let report = await monitor.stop()
        #expect(report != nil)
    }

    @Test("warning emitted when dimension drops below 0.40")
    func warningOnThresholdCross() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )

        let recorder = WarningRecorder()
        await monitor.setWarningHandler { dimension, score in
            Task { await recorder.record(dimension: dimension, score: score) }
        }

        await monitor.start()
        // RTT of 180ms → latency = 1 - 180/200 = 0.10 → below 0.40
        await monitor.recordRTT(180.0)

        var iterator = await monitor.scores.makeAsyncIterator()
        _ = await iterator.next()

        // Allow warning handler Task to complete
        try await Task.sleep(for: .milliseconds(20))

        let warnings = await recorder.warnings
        #expect(!warnings.isEmpty)
        #expect(warnings.first?.dimension == .latency)

        _ = await monitor.stop()
    }
}

/// Thread-safe recorder for quality warnings in tests.
private actor WarningRecorder {

    struct Warning {
        let dimension: QualityDimension
        let score: Double
    }

    var warnings: [Warning] = []

    func record(dimension: QualityDimension, score: Double) {
        warnings.append(Warning(dimension: dimension, score: score))
    }
}
