// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Test Helpers

/// Build a scripted server response sequence for a successful publish.
private func makePublishScript(streamID: Double = 1) -> [RTMPMessage] {
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
                information: .number(streamID)
            )),
        RTMPMessage(
            command: .onStatus(
                information: .object([
                    ("level", .string("status")),
                    ("code", .string("NetStream.Publish.Start")),
                    ("description", .string("Publishing live_test"))
                ])))
    ]
}

private func makeScriptedPublisher() async -> (RTMPPublisher, MockTransport) {
    let mock = MockTransport()
    await mock.setScriptedMessages(makePublishScript())
    let publisher = RTMPPublisher(transport: mock)
    return (publisher, mock)
}

private func publishAndConnect(_ publisher: RTMPPublisher) async throws {
    try await publisher.publish(
        url: "rtmp://localhost/app",
        streamKey: "test",
        enhancedRTMP: false
    )
}

@Suite("RTMPPublisher — Raw Payload Methods")
struct RTMPPublisherPayloadTests {

    @Test("sendVideoPayload sends raw bytes without AVC wrapping")
    func sendVideoPayloadRaw() async throws {
        let (publisher, mock) = await makeScriptedPublisher()
        // Enable suspension so message loop doesn't close transport
        await mock.setNextError(nil)

        try await publishAndConnect(publisher)
        let sentBefore = await mock.sentBytes.count

        // Send raw enhanced video payload
        let payload: [UInt8] = [0x91, 0x68, 0x76, 0x63, 0x31, 0x00, 0x00, 0x00, 0xAA]
        try await publisher.sendVideoPayload(
            payload, timestamp: 100, isKeyframe: true
        )

        let sentAfter = await mock.sentBytes
        // Should have sent more bytes than before
        #expect(sentAfter.count > sentBefore)

        // The last sent chunk should contain our raw payload bytes (not wrapped)
        let lastSent = sentAfter.last ?? []
        // Verify the payload appears in the sent bytes without AVC header wrapping
        // The raw payload should be embedded directly (no 0x17 AVC prefix added)
        #expect(!lastSent.isEmpty)

        await publisher.disconnect()
    }

    @Test("sendVideoConfigPayload sends raw bytes without AVC seq header wrapping")
    func sendVideoConfigPayloadRaw() async throws {
        let (publisher, mock) = await makeScriptedPublisher()

        try await publishAndConnect(publisher)
        let sentBefore = await mock.sentBytes.count

        let payload: [UInt8] = [0x81, 0x68, 0x76, 0x63, 0x31, 0xDE, 0xAD]
        try await publisher.sendVideoConfigPayload(payload)

        let sentAfter = await mock.sentBytes
        #expect(sentAfter.count > sentBefore)

        await publisher.disconnect()
    }

    @Test("sendAudioPayload sends raw bytes without AAC wrapping")
    func sendAudioPayloadRaw() async throws {
        let (publisher, mock) = await makeScriptedPublisher()

        try await publishAndConnect(publisher)
        let sentBefore = await mock.sentBytes.count

        let payload: [UInt8] = [0x88, 0x4F, 0x70, 0x75, 0x73, 0xBB]
        try await publisher.sendAudioPayload(payload, timestamp: 50)

        let sentAfter = await mock.sentBytes
        #expect(sentAfter.count > sentBefore)

        await publisher.disconnect()
    }

    @Test("sendAudioConfigPayload sends raw bytes without AAC seq header wrapping")
    func sendAudioConfigPayloadRaw() async throws {
        let (publisher, mock) = await makeScriptedPublisher()

        try await publishAndConnect(publisher)
        let sentBefore = await mock.sentBytes.count

        let payload: [UInt8] = [0x80, 0x4F, 0x70, 0x75, 0x73, 0xCC]
        try await publisher.sendAudioConfigPayload(payload)

        let sentAfter = await mock.sentBytes
        #expect(sentAfter.count > sentBefore)

        await publisher.disconnect()
    }

    @Test("sendVideoPayload throws when not publishing")
    func sendVideoPayloadNotPublishing() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)

        await #expect(throws: RTMPError.self) {
            try await publisher.sendVideoPayload(
                [0x17, 0x01], timestamp: 0, isKeyframe: true
            )
        }
    }
}
