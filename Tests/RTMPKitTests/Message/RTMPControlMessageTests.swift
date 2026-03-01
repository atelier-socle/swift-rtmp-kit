// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPControlMessage — Encoding")
struct RTMPControlMessageEncodeTests {

    @Test("setChunkSize encodes to 4 bytes BE")
    func encodeSetChunkSize() {
        let msg = RTMPControlMessage.setChunkSize(4096)
        let bytes = msg.encode()
        #expect(bytes.count == 4)
        #expect(bytes[0] == 0x00)
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x10)
        #expect(bytes[3] == 0x00)
    }

    @Test("setChunkSize MSB enforcement")
    func encodeSetChunkSizeMSBMasked() {
        let msg = RTMPControlMessage.setChunkSize(0x8000_0001)
        let bytes = msg.encode()
        // MSB should be masked off
        #expect(bytes[0] == 0x00)
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x00)
        #expect(bytes[3] == 0x01)
    }

    @Test("abort encodes CSID to 4 bytes BE")
    func encodeAbort() {
        let msg = RTMPControlMessage.abort(chunkStreamID: 3)
        let bytes = msg.encode()
        #expect(bytes.count == 4)
        #expect(bytes == [0x00, 0x00, 0x00, 0x03])
    }

    @Test("acknowledgement encodes sequence number")
    func encodeAcknowledgement() {
        let msg = RTMPControlMessage.acknowledgement(sequenceNumber: 0x0001_0000)
        let bytes = msg.encode()
        #expect(bytes.count == 4)
        #expect(bytes == [0x00, 0x01, 0x00, 0x00])
    }

    @Test("windowAcknowledgementSize encodes window size")
    func encodeWindowAckSize() {
        let msg = RTMPControlMessage.windowAcknowledgementSize(2_500_000)
        let bytes = msg.encode()
        #expect(bytes.count == 4)
    }

    @Test("setPeerBandwidth encodes 5 bytes")
    func encodeSetPeerBandwidth() {
        let msg = RTMPControlMessage.setPeerBandwidth(
            windowSize: 2_500_000, limitType: .dynamic
        )
        let bytes = msg.encode()
        #expect(bytes.count == 5)
        #expect(bytes[4] == 2)  // dynamic
    }

    @Test("setPeerBandwidth hard limit type")
    func encodePeerBandwidthHard() {
        let msg = RTMPControlMessage.setPeerBandwidth(
            windowSize: 1000, limitType: .hard
        )
        let bytes = msg.encode()
        #expect(bytes[4] == 0)
    }

    @Test("setPeerBandwidth soft limit type")
    func encodePeerBandwidthSoft() {
        let msg = RTMPControlMessage.setPeerBandwidth(
            windowSize: 1000, limitType: .soft
        )
        let bytes = msg.encode()
        #expect(bytes[4] == 1)
    }

    // MARK: - Type IDs

    @Test("Type IDs are correct")
    func typeIDs() {
        #expect(RTMPControlMessage.setChunkSize(128).typeID == 1)
        #expect(RTMPControlMessage.abort(chunkStreamID: 0).typeID == 2)
        #expect(RTMPControlMessage.acknowledgement(sequenceNumber: 0).typeID == 3)
        #expect(RTMPControlMessage.windowAcknowledgementSize(0).typeID == 5)
        #expect(
            RTMPControlMessage.setPeerBandwidth(windowSize: 0, limitType: .hard).typeID == 6
        )
    }
}

@Suite("RTMPControlMessage — Decoding")
struct RTMPControlMessageDecodeTests {

    @Test("Decode setChunkSize from known bytes")
    func decodeSetChunkSize() throws {
        let msg = try RTMPControlMessage.decode(
            typeID: 1, payload: [0x00, 0x00, 0x10, 0x00]
        )
        #expect(msg == .setChunkSize(4096))
    }

    @Test("Decode setChunkSize masks MSB")
    func decodeSetChunkSizeMSB() throws {
        let msg = try RTMPControlMessage.decode(
            typeID: 1, payload: [0x80, 0x00, 0x00, 0x01]
        )
        #expect(msg == .setChunkSize(1))
    }

    @Test("Decode abort")
    func decodeAbort() throws {
        let msg = try RTMPControlMessage.decode(
            typeID: 2, payload: [0x00, 0x00, 0x00, 0x05]
        )
        #expect(msg == .abort(chunkStreamID: 5))
    }

    @Test("Decode acknowledgement")
    func decodeAcknowledgement() throws {
        let msg = try RTMPControlMessage.decode(
            typeID: 3, payload: [0x00, 0x01, 0x00, 0x00]
        )
        #expect(msg == .acknowledgement(sequenceNumber: 0x0001_0000))
    }

    @Test("Decode windowAcknowledgementSize")
    func decodeWindowAckSize() throws {
        let msg = try RTMPControlMessage.decode(
            typeID: 5, payload: [0x00, 0x26, 0x25, 0xA0]
        )
        #expect(msg == .windowAcknowledgementSize(2_500_000))
    }

    @Test("Decode setPeerBandwidth hard")
    func decodeSetPeerBandwidthHard() throws {
        let msg = try RTMPControlMessage.decode(
            typeID: 6, payload: [0x00, 0x26, 0x25, 0xA0, 0x00]
        )
        #expect(msg == .setPeerBandwidth(windowSize: 2_500_000, limitType: .hard))
    }

    @Test("Decode setPeerBandwidth soft")
    func decodeSetPeerBandwidthSoft() throws {
        let msg = try RTMPControlMessage.decode(
            typeID: 6, payload: [0x00, 0x00, 0x03, 0xE8, 0x01]
        )
        #expect(msg == .setPeerBandwidth(windowSize: 1000, limitType: .soft))
    }

    @Test("Decode setPeerBandwidth dynamic")
    func decodeSetPeerBandwidthDynamic() throws {
        let msg = try RTMPControlMessage.decode(
            typeID: 6, payload: [0x00, 0x00, 0x03, 0xE8, 0x02]
        )
        #expect(msg == .setPeerBandwidth(windowSize: 1000, limitType: .dynamic))
    }

    // MARK: - Error Cases

    @Test("Unknown type ID throws")
    func unknownTypeID() {
        #expect(throws: MessageError.self) {
            try RTMPControlMessage.decode(typeID: 4, payload: [])
        }
    }

    @Test("Type 7 throws unknown")
    func unknownType7() {
        #expect(throws: MessageError.self) {
            try RTMPControlMessage.decode(typeID: 7, payload: [0x00, 0x00, 0x00, 0x00])
        }
    }

    @Test("Truncated setChunkSize payload throws")
    func truncatedSetChunkSize() {
        #expect(throws: MessageError.self) {
            try RTMPControlMessage.decode(typeID: 1, payload: [0x00, 0x00])
        }
    }

    @Test("Truncated setPeerBandwidth payload throws")
    func truncatedSetPeerBandwidth() {
        #expect(throws: MessageError.self) {
            try RTMPControlMessage.decode(typeID: 6, payload: [0x00, 0x00, 0x00, 0x00])
        }
    }

    @Test("Invalid limit type throws")
    func invalidLimitType() {
        #expect(throws: MessageError.self) {
            try RTMPControlMessage.decode(
                typeID: 6, payload: [0x00, 0x00, 0x00, 0x00, 0x05]
            )
        }
    }

    // MARK: - Roundtrip

    @Test("Roundtrip setChunkSize")
    func roundtripSetChunkSize() throws {
        let original = RTMPControlMessage.setChunkSize(4096)
        let decoded = try RTMPControlMessage.decode(typeID: original.typeID, payload: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip abort")
    func roundtripAbort() throws {
        let original = RTMPControlMessage.abort(chunkStreamID: 42)
        let decoded = try RTMPControlMessage.decode(typeID: original.typeID, payload: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip acknowledgement")
    func roundtripAck() throws {
        let original = RTMPControlMessage.acknowledgement(sequenceNumber: 123456)
        let decoded = try RTMPControlMessage.decode(typeID: original.typeID, payload: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip windowAcknowledgementSize")
    func roundtripWindowAck() throws {
        let original = RTMPControlMessage.windowAcknowledgementSize(2_500_000)
        let decoded = try RTMPControlMessage.decode(typeID: original.typeID, payload: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip setPeerBandwidth")
    func roundtripPeerBandwidth() throws {
        let original = RTMPControlMessage.setPeerBandwidth(
            windowSize: 2_500_000, limitType: .dynamic
        )
        let decoded = try RTMPControlMessage.decode(typeID: original.typeID, payload: original.encode())
        #expect(decoded == original)
    }

    // MARK: - Edge Cases

    @Test("setChunkSize minimum (1)")
    func chunkSizeMin() throws {
        let original = RTMPControlMessage.setChunkSize(1)
        let decoded = try RTMPControlMessage.decode(typeID: 1, payload: original.encode())
        #expect(decoded == .setChunkSize(1))
    }

    @Test("setChunkSize maximum (0x7FFFFFFF)")
    func chunkSizeMax() throws {
        let original = RTMPControlMessage.setChunkSize(0x7FFF_FFFF)
        let decoded = try RTMPControlMessage.decode(typeID: 1, payload: original.encode())
        #expect(decoded == .setChunkSize(0x7FFF_FFFF))
    }
}
