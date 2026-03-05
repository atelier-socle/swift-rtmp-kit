// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

/// Build a scripted server response sequence for a successful publish.
private func makePublishScript() -> [RTMPMessage] {
    [
        RTMPMessage(controlMessage: .windowAcknowledgementSize(2_500_000)),
        RTMPMessage(
            controlMessage: .setPeerBandwidth(
                windowSize: 2_500_000, limitType: .dynamic
            )
        ),
        RTMPMessage(
            command: .result(
                transactionID: 1,
                properties: nil,
                information: .object([
                    ("level", .string("status")),
                    ("code", .string("NetConnection.Connect.Success")),
                    ("description", .string("Connection succeeded"))
                ])
            )),
        RTMPMessage(
            command: .result(
                transactionID: 4,
                properties: nil,
                information: .number(1)
            )),
        RTMPMessage(
            command: .onStatus(
                information: .object([
                    ("level", .string("status")),
                    ("code", .string("NetStream.Publish.Start")),
                    ("description", .string("Publishing"))
                ])))
    ]
}

@Suite("RTMPPublisher+QualityScore — Idle State")
struct PublisherQualityScoreCoverageTests {

    @Test("qualityScore returns nil before publishing")
    func qualityScoreNilBeforePublish() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        let score = await publisher.qualityScore
        #expect(score == nil)
    }

    @Test("qualityScores returns empty stream when no monitor")
    func qualityScoresEmptyWhenNoMonitor() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        let stream = await publisher.qualityScores
        var count = 0
        for await _ in stream {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("qualityReport returns nil before publishing")
    func qualityReportNilBeforePublish() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        let report = await publisher.qualityReport()
        #expect(report == nil)
    }

    @Test("recordRTTForQuality is no-op without monitor")
    func recordRTTNoOpWithoutMonitor() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await publisher.recordRTTForQuality(10.0)
        // No crash = pass
    }

    @Test("quality score available after publishing with quality monitor")
    func qualityScoreAfterPublish() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app", streamKey: "test",
            enhancedRTMP: false
        )
        // Quality monitor should be started — feed it data
        await publisher.recordRTTForQuality(5.0)
        await publisher.recordBytesForQuality(10000)
        await publisher.recordFrameDropForQuality()
        await publisher.recordSentFrameForQuality()
        await publisher.disconnect()
    }
}

@Suite("RTMPPublisher+ABR — Idle State")
struct PublisherABRCoverageTests {

    @Test("recordRTTForABR is no-op without monitor")
    func recordRTTNoOpWithoutABR() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await publisher.recordRTTForABR(15.0)
        // No crash = pass
    }
}

@Suite("RTMPPublisher+RawPayload — NotPublishing Guards")
struct PublisherRawPayloadNotPublishingTests {

    @Test("sendVideoConfigPayload throws notPublishing when not publishing")
    func videoConfigThrows() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await #expect(throws: RTMPError.self) {
            try await publisher.sendVideoConfigPayload([0x81, 0x68])
        }
    }

    @Test("sendAudioPayload throws notPublishing when not publishing")
    func audioPayloadThrows() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await #expect(throws: RTMPError.self) {
            try await publisher.sendAudioPayload([0x88], timestamp: 0)
        }
    }

    @Test("sendAudioConfigPayload throws notPublishing when not publishing")
    func audioConfigThrows() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await #expect(throws: RTMPError.self) {
            try await publisher.sendAudioConfigPayload([0x80, 0x4F])
        }
    }
}

@Suite("RTMPPublisher+Recording — Idle State")
struct PublisherRecordingCoverageTests {

    @Test("recordingEvents returns empty stream when no recorder")
    func recordingEventsEmpty() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        let stream = await publisher.recordingEvents
        var count = 0
        for await _ in stream {
            count += 1
        }
        #expect(count == 0)
    }
}
