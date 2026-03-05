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

// MARK: - Metadata Not Publishing Tests

@Suite("RTMPPublisher+Metadata — Not Publishing Guards")
struct PublisherMetadataNotPublishingTests {

    @Test("updateStreamInfo throws notPublishing when not publishing")
    func updateStreamInfoThrows() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await #expect(throws: RTMPError.self) {
            try await publisher.updateStreamInfo(
                StreamMetadata()
            )
        }
    }

    @Test("send timed metadata throws notPublishing when not publishing")
    func sendTimedMetadataThrows() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await #expect(throws: RTMPError.self) {
            try await publisher.send(.text("test", timestamp: 0))
        }
    }

    @Test("sendText throws notPublishing when not publishing")
    func sendTextThrows() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await #expect(throws: RTMPError.self) {
            try await publisher.sendText("test", timestamp: 0)
        }
    }

    @Test("sendCuePoint throws notPublishing when not publishing")
    func sendCuePointThrows() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await #expect(throws: RTMPError.self) {
            try await publisher.sendCuePoint(
                CuePoint(name: "test", time: 0)
            )
        }
    }

    @Test("sendCaption throws notPublishing when not publishing")
    func sendCaptionThrows() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await #expect(throws: RTMPError.self) {
            try await publisher.sendCaption(
                CaptionData(text: "test", timestamp: 0.0)
            )
        }
    }

    @Test("sendDataMessagePayload throws notPublishing when not publishing")
    func sendDataMessagePayloadThrows() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        await #expect(throws: RTMPError.self) {
            try await publisher.sendDataMessagePayload([0x02, 0x00])
        }
    }
}

// MARK: - Metadata While Publishing Tests

@Suite("RTMPPublisher+Metadata — While Publishing")
struct PublisherMetadataWhilePublishingTests {

    @Test("updateStreamInfo succeeds when publishing")
    func updateStreamInfoWhenPublishing() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app", streamKey: "test",
            enhancedRTMP: false
        )
        // Should not throw — metadata updater is set up after publish
        try await publisher.updateStreamInfo(
            StreamMetadata()
        )
        await publisher.disconnect()
    }

    @Test("send timed metadata succeeds when publishing")
    func sendTimedMetadataWhenPublishing() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app", streamKey: "test",
            enhancedRTMP: false
        )
        try await publisher.send(.text("hello", timestamp: 100))
        await publisher.disconnect()
    }

    @Test("sendText succeeds when publishing")
    func sendTextWhenPublishing() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app", streamKey: "test",
            enhancedRTMP: false
        )
        try await publisher.sendText("hello", timestamp: 100)
        await publisher.disconnect()
    }

    @Test("sendCuePoint succeeds when publishing")
    func sendCuePointWhenPublishing() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app", streamKey: "test",
            enhancedRTMP: false
        )
        try await publisher.sendCuePoint(
            CuePoint(name: "ad-start", time: 1.0)
        )
        await publisher.disconnect()
    }

    @Test("sendCaption succeeds when publishing")
    func sendCaptionWhenPublishing() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app", streamKey: "test",
            enhancedRTMP: false
        )
        try await publisher.sendCaption(
            CaptionData(text: "Hello world", timestamp: 2.0)
        )
        await publisher.disconnect()
    }

    @Test("sendDataMessagePayload succeeds when publishing")
    func sendDataMessagePayloadWhenPublishing() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app", streamKey: "test",
            enhancedRTMP: false
        )
        try await publisher.sendDataMessagePayload([0x02, 0x00, 0x0A])
        await publisher.disconnect()
    }
}
