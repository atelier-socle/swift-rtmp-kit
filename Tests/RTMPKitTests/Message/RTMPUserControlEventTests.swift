// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPUserControlEvent — Encoding")
struct RTMPUserControlEventEncodeTests {

    @Test("streamBegin encodes to 6 bytes")
    func encodeStreamBegin() {
        let event = RTMPUserControlEvent.streamBegin(streamID: 1)
        let bytes = event.encode()
        #expect(bytes.count == 6)
        // Event type 0
        #expect(bytes[0] == 0x00)
        #expect(bytes[1] == 0x00)
        // Stream ID 1
        #expect(bytes[2] == 0x00)
        #expect(bytes[3] == 0x00)
        #expect(bytes[4] == 0x00)
        #expect(bytes[5] == 0x01)
    }

    @Test("streamEOF encodes to 6 bytes")
    func encodeStreamEOF() {
        let event = RTMPUserControlEvent.streamEOF(streamID: 1)
        let bytes = event.encode()
        #expect(bytes.count == 6)
        #expect(bytes[0] == 0x00)
        #expect(bytes[1] == 0x01)
    }

    @Test("streamDry encodes to 6 bytes")
    func encodeStreamDry() {
        let event = RTMPUserControlEvent.streamDry(streamID: 1)
        let bytes = event.encode()
        #expect(bytes.count == 6)
        #expect(bytes[0] == 0x00)
        #expect(bytes[1] == 0x02)
    }

    @Test("setBufferLength encodes to 10 bytes")
    func encodeSetBufferLength() {
        let event = RTMPUserControlEvent.setBufferLength(
            streamID: 1, bufferLengthMs: 3000
        )
        let bytes = event.encode()
        #expect(bytes.count == 10)
        // Event type 3
        #expect(bytes[0] == 0x00)
        #expect(bytes[1] == 0x03)
        // Stream ID 1
        #expect(bytes[2] == 0x00)
        #expect(bytes[3] == 0x00)
        #expect(bytes[4] == 0x00)
        #expect(bytes[5] == 0x01)
        // Buffer length 3000 = 0x00000BB8
        #expect(bytes[6] == 0x00)
        #expect(bytes[7] == 0x00)
        #expect(bytes[8] == 0x0B)
        #expect(bytes[9] == 0xB8)
    }

    @Test("pingRequest encodes to 6 bytes")
    func encodePingRequest() {
        let event = RTMPUserControlEvent.pingRequest(timestamp: 12345)
        let bytes = event.encode()
        #expect(bytes.count == 6)
        #expect(bytes[0] == 0x00)
        #expect(bytes[1] == 0x06)
    }

    @Test("pingResponse encodes to 6 bytes")
    func encodePingResponse() {
        let event = RTMPUserControlEvent.pingResponse(timestamp: 12345)
        let bytes = event.encode()
        #expect(bytes.count == 6)
        #expect(bytes[0] == 0x00)
        #expect(bytes[1] == 0x07)
    }

    // MARK: - Event Type IDs

    @Test("Event type IDs are correct")
    func eventTypeIDs() {
        #expect(RTMPUserControlEvent.streamBegin(streamID: 0).eventTypeID == 0)
        #expect(RTMPUserControlEvent.streamEOF(streamID: 0).eventTypeID == 1)
        #expect(RTMPUserControlEvent.streamDry(streamID: 0).eventTypeID == 2)
        #expect(
            RTMPUserControlEvent.setBufferLength(streamID: 0, bufferLengthMs: 0).eventTypeID == 3
        )
        #expect(RTMPUserControlEvent.pingRequest(timestamp: 0).eventTypeID == 6)
        #expect(RTMPUserControlEvent.pingResponse(timestamp: 0).eventTypeID == 7)
    }

    @Test("Message type ID is 4")
    func messageTypeID() {
        #expect(RTMPUserControlEvent.typeID == 4)
    }
}

@Suite("RTMPUserControlEvent — Decoding")
struct RTMPUserControlEventDecodeTests {

    @Test("Decode streamBegin")
    func decodeStreamBegin() throws {
        let bytes: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x01]
        let event = try RTMPUserControlEvent.decode(from: bytes)
        #expect(event == .streamBegin(streamID: 1))
    }

    @Test("Decode streamEOF")
    func decodeStreamEOF() throws {
        let bytes: [UInt8] = [0x00, 0x01, 0x00, 0x00, 0x00, 0x02]
        let event = try RTMPUserControlEvent.decode(from: bytes)
        #expect(event == .streamEOF(streamID: 2))
    }

    @Test("Decode streamDry")
    func decodeStreamDry() throws {
        let bytes: [UInt8] = [0x00, 0x02, 0x00, 0x00, 0x00, 0x03]
        let event = try RTMPUserControlEvent.decode(from: bytes)
        #expect(event == .streamDry(streamID: 3))
    }

    @Test("Decode setBufferLength")
    func decodeSetBufferLength() throws {
        let bytes: [UInt8] = [
            0x00, 0x03,
            0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x0B, 0xB8
        ]
        let event = try RTMPUserControlEvent.decode(from: bytes)
        #expect(event == .setBufferLength(streamID: 1, bufferLengthMs: 3000))
    }

    @Test("Decode pingRequest")
    func decodePingRequest() throws {
        let bytes: [UInt8] = [0x00, 0x06, 0x00, 0x00, 0x30, 0x39]
        let event = try RTMPUserControlEvent.decode(from: bytes)
        #expect(event == .pingRequest(timestamp: 12345))
    }

    @Test("Decode pingResponse")
    func decodePingResponse() throws {
        let bytes: [UInt8] = [0x00, 0x07, 0x00, 0x00, 0x30, 0x39]
        let event = try RTMPUserControlEvent.decode(from: bytes)
        #expect(event == .pingResponse(timestamp: 12345))
    }

    // MARK: - Error Cases

    @Test("Decode unknown event type throws")
    func unknownEventType() {
        let bytes: [UInt8] = [0x00, 0x0A, 0x00, 0x00, 0x00, 0x01]
        #expect(throws: MessageError.self) {
            try RTMPUserControlEvent.decode(from: bytes)
        }
    }

    @Test("Truncated payload throws")
    func truncatedPayload() {
        #expect(throws: MessageError.self) {
            try RTMPUserControlEvent.decode(from: [0x00])
        }
    }

    @Test("Truncated streamBegin payload throws")
    func truncatedStreamBegin() {
        let bytes: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        #expect(throws: MessageError.self) {
            try RTMPUserControlEvent.decode(from: bytes)
        }
    }

    @Test("Truncated setBufferLength payload throws")
    func truncatedSetBufferLength() {
        let bytes: [UInt8] = [0x00, 0x03, 0x00, 0x00, 0x00, 0x01]
        #expect(throws: MessageError.self) {
            try RTMPUserControlEvent.decode(from: bytes)
        }
    }

    // MARK: - Roundtrip

    @Test("Roundtrip streamBegin")
    func roundtripStreamBegin() throws {
        let original = RTMPUserControlEvent.streamBegin(streamID: 42)
        let decoded = try RTMPUserControlEvent.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip streamEOF")
    func roundtripStreamEOF() throws {
        let original = RTMPUserControlEvent.streamEOF(streamID: 1)
        let decoded = try RTMPUserControlEvent.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip setBufferLength")
    func roundtripSetBufferLength() throws {
        let original = RTMPUserControlEvent.setBufferLength(
            streamID: 1, bufferLengthMs: 5000
        )
        let decoded = try RTMPUserControlEvent.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip pingRequest")
    func roundtripPingRequest() throws {
        let original = RTMPUserControlEvent.pingRequest(timestamp: 99999)
        let decoded = try RTMPUserControlEvent.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip pingResponse")
    func roundtripPingResponse() throws {
        let original = RTMPUserControlEvent.pingResponse(timestamp: 99999)
        let decoded = try RTMPUserControlEvent.decode(from: original.encode())
        #expect(decoded == original)
    }
}
