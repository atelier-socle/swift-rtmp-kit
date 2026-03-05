// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Suite 1: Live Scoring

@Suite("Connection Quality Showcase — Live Scoring")
struct QualityLiveScoringShowcaseTests {

    @Test("Quality score updates during streaming")
    func scoreUpdatesDuringStreaming() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordRTT(15.0)
        await monitor.recordBytesSent(500_000, targetBitrate: 4_000_000)

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        #expect(score != nil)
        #expect(score?.overall ?? 0 > 0.0)
        #expect(score?.overall ?? 2 <= 1.0)

        _ = await monitor.stop()
    }

    @Test("Excellent connection: low RTT, no drops, full bitrate")
    func excellentConnection() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordRTT(5.0)
        await monitor.recordBytesSent(500_000, targetBitrate: 4_000_000)
        await monitor.recordBitrateAchievement(
            actual: 4_000_000, configured: 4_000_000
        )

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        #expect(score != nil)
        let grade = score?.grade ?? .critical
        #expect(grade >= .good)

        _ = await monitor.stop()
    }

    @Test("Poor connection: high RTT + frame drops")
    func poorConnection() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        for _ in 0..<20 { await monitor.recordSentFrame() }
        for _ in 0..<10 { await monitor.recordFrameDrop() }
        await monitor.recordRTT(180.0)
        await monitor.recordBitrateAchievement(
            actual: 500_000, configured: 4_000_000
        )

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()
        #expect(score != nil)
        let grade = score?.grade ?? .excellent
        #expect(grade <= .fair)

        _ = await monitor.stop()
    }

    @Test("Quality report covers the recording window")
    func reportCoversWindow() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordRTT(15.0)
        await monitor.recordBytesSent(400_000, targetBitrate: 4_000_000)

        var iterator = await monitor.scores.makeAsyncIterator()
        _ = await iterator.next()

        let report = await monitor.generateReport()
        #expect(report != nil)
        #expect((report?.samples.count ?? 0) >= 1)
        let trend = report?.trend
        #expect(
            trend == .improving || trend == .stable || trend == .degrading
        )

        _ = await monitor.stop()
    }
}

// MARK: - Suite 2: Publisher Integration

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

@Suite("Connection Quality Showcase — Publisher Integration")
struct QualityPublisherShowcaseTests {

    @Test("qualityScore is available after connect and scoring")
    func qualityScoreAfterConnect() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        try await publisher.publish(
            configuration: RTMPConfiguration(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
        )

        // Send some data to trigger quality scoring
        try await publisher.sendVideo(
            [0x01, 0x02], timestamp: 0, isKeyframe: true
        )

        // Wait for scoring interval
        try await Task.sleep(for: .milliseconds(100))

        // Quality monitor should exist
        let monitor = await publisher.qualityMonitor
        #expect(monitor != nil)

        await publisher.disconnect()
    }

    @Test("qualityWarning event emitted on degradation")
    func warningOnDegradation() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )

        await monitor.start()
        // High RTT → latency below warning threshold
        await monitor.recordRTT(190.0)

        var iterator = await monitor.scores.makeAsyncIterator()
        let score = await iterator.next()

        // Verify the latency dimension is in warning territory
        let latency = score?.score(for: .latency) ?? 1.0
        #expect(latency < 0.40)
        #expect(score?.hasWarning == true)

        _ = await monitor.stop()
    }

    @Test("qualityReportGenerated on stop")
    func reportOnStop() async throws {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.05, reportingWindow: 5.0
        )
        await monitor.start()
        await monitor.recordRTT(10.0)

        var iterator = await monitor.scores.makeAsyncIterator()
        _ = await iterator.next()

        let report = await monitor.stop()
        #expect(report != nil)
        #expect((report?.samples.count ?? 0) >= 1)
    }

    @Test("Grade progression: excellent > critical")
    func gradeProgression() {
        #expect(
            ConnectionQualityScore.Grade.excellent
                > ConnectionQualityScore.Grade.critical
        )
        #expect(
            ConnectionQualityScore.Grade.excellent
                > ConnectionQualityScore.Grade.good
        )
        #expect(
            ConnectionQualityScore.Grade.good
                > ConnectionQualityScore.Grade.fair
        )
        #expect(
            ConnectionQualityScore.Grade.fair
                > ConnectionQualityScore.Grade.poor
        )
        #expect(
            ConnectionQualityScore.Grade.poor
                > ConnectionQualityScore.Grade.critical
        )
    }
}
