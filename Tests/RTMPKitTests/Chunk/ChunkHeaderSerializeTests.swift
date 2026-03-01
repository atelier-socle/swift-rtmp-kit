// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkHeader — Serialization")
struct ChunkHeaderSerializeTests {

    // MARK: - Basic Header CSID Encoding

    @Test("1-byte basic header for CSID 2-63")
    func basicHeader1Byte() {
        let header = ChunkHeader(format: .full, chunkStreamID: 3)
        let bytes = header.serialize()
        #expect(bytes[0] & 0x3F == 3)
        #expect(bytes[0] >> 6 == 0)
    }

    @Test("2-byte basic header for CSID 64-319")
    func basicHeader2Byte() {
        let header = ChunkHeader(format: .full, chunkStreamID: 200)
        let bytes = header.serialize()
        #expect(bytes[0] & 0x3F == 0)
        #expect(bytes[1] == 200 - 64)
    }

    @Test("3-byte basic header for CSID 320+")
    func basicHeader3Byte() {
        let header = ChunkHeader(format: .full, chunkStreamID: 1000)
        let bytes = header.serialize()
        #expect(bytes[0] & 0x3F == 1)
        let adjusted = 1000 - 64
        #expect(bytes[1] == UInt8(adjusted & 0xFF))
        #expect(bytes[2] == UInt8((adjusted >> 8) & 0xFF))
    }

    @Test("fmt bits in first byte")
    func fmtBitsEncoding() {
        let fmt0 = ChunkHeader(format: .full, chunkStreamID: 3).serialize()
        #expect(fmt0[0] >> 6 == 0)
        let fmt1 = ChunkHeader(format: .sameStream, chunkStreamID: 3).serialize()
        #expect(fmt1[0] >> 6 == 1)
        let fmt2 = ChunkHeader(format: .timestampOnly, chunkStreamID: 3).serialize()
        #expect(fmt2[0] >> 6 == 2)
        let fmt3 = ChunkHeader(format: .continuation, chunkStreamID: 3).serialize()
        #expect(fmt3[0] >> 6 == 3)
    }

    // MARK: - Fmt 0 Full Header

    @Test("Fmt 0 encodes 11-byte message header")
    func fmt0MessageHeader() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 1000,
            messageLength: 256,
            messageTypeID: 20,
            messageStreamID: 1
        )
        let bytes = header.serialize()
        // 1 basic header + 11 message header = 12
        #expect(bytes.count == 12)
    }

    @Test("Fmt 0 timestamp is big-endian")
    func fmt0TimestampBE() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 0x010203
        )
        let bytes = header.serialize()
        #expect(bytes[1] == 0x01)
        #expect(bytes[2] == 0x02)
        #expect(bytes[3] == 0x03)
    }

    @Test("Fmt 0 message length is big-endian")
    func fmt0MessageLengthBE() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            messageLength: 0x040506
        )
        let bytes = header.serialize()
        #expect(bytes[4] == 0x04)
        #expect(bytes[5] == 0x05)
        #expect(bytes[6] == 0x06)
    }

    @Test("Fmt 0 message type ID is single byte")
    func fmt0MessageTypeID() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            messageTypeID: 0x14
        )
        let bytes = header.serialize()
        #expect(bytes[7] == 0x14)
    }

    @Test("Fmt 0 message stream ID is LITTLE-endian")
    func fmt0MessageStreamIDLE() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            messageStreamID: 0x0102_0304
        )
        let bytes = header.serialize()
        // LE: least significant byte first
        #expect(bytes[8] == 0x04)
        #expect(bytes[9] == 0x03)
        #expect(bytes[10] == 0x02)
        #expect(bytes[11] == 0x01)
    }

    // MARK: - Fmt 1 Same Stream Header

    @Test("Fmt 1 encodes 7-byte message header (no stream ID)")
    func fmt1MessageHeader() {
        let header = ChunkHeader(
            format: .sameStream,
            chunkStreamID: 3,
            timestamp: 500,
            messageLength: 100,
            messageTypeID: 9
        )
        let bytes = header.serialize()
        // 1 basic + 7 message = 8
        #expect(bytes.count == 8)
    }

    @Test("Fmt 1 has timestamp delta, length, type but no stream ID")
    func fmt1Fields() {
        let header = ChunkHeader(
            format: .sameStream,
            chunkStreamID: 3,
            timestamp: 0x000100,
            messageLength: 0x000200,
            messageTypeID: 8
        )
        let bytes = header.serialize()
        // timestamp delta
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x01)
        #expect(bytes[3] == 0x00)
        // message length
        #expect(bytes[4] == 0x00)
        #expect(bytes[5] == 0x02)
        #expect(bytes[6] == 0x00)
        // type ID
        #expect(bytes[7] == 0x08)
    }

    // MARK: - Fmt 2 Timestamp Only Header

    @Test("Fmt 2 encodes 3-byte message header")
    func fmt2MessageHeader() {
        let header = ChunkHeader(
            format: .timestampOnly,
            chunkStreamID: 3,
            timestamp: 33
        )
        let bytes = header.serialize()
        // 1 basic + 3 message = 4
        #expect(bytes.count == 4)
    }

    @Test("Fmt 2 only contains timestamp delta")
    func fmt2TimestampOnly() {
        let header = ChunkHeader(
            format: .timestampOnly,
            chunkStreamID: 3,
            timestamp: 0x000021
        )
        let bytes = header.serialize()
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x00)
        #expect(bytes[3] == 0x21)
    }

    // MARK: - Fmt 3 Continuation Header

    @Test("Fmt 3 has 0-byte message header")
    func fmt3NoMessageHeader() {
        let header = ChunkHeader(
            format: .continuation,
            chunkStreamID: 3
        )
        let bytes = header.serialize()
        // 1 basic header only
        #expect(bytes.count == 1)
    }

    // MARK: - Extended Timestamp

    @Test("Extended timestamp at exact boundary 0xFFFFFF")
    func extendedTimestampBoundary() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 0xFFFFFF
        )
        #expect(header.hasExtendedTimestamp)
        let bytes = header.serialize()
        // 1 basic + 11 message + 4 extended = 16
        #expect(bytes.count == 16)
        // 24-bit field should be 0xFFFFFF
        #expect(bytes[1] == 0xFF)
        #expect(bytes[2] == 0xFF)
        #expect(bytes[3] == 0xFF)
        // extended: 0x00FFFFFF BE
        #expect(bytes[12] == 0x00)
        #expect(bytes[13] == 0xFF)
        #expect(bytes[14] == 0xFF)
        #expect(bytes[15] == 0xFF)
    }

    @Test("Extended timestamp just over boundary")
    func extendedTimestampOver() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 0x0100_0000
        )
        #expect(header.hasExtendedTimestamp)
        let bytes = header.serialize()
        #expect(bytes.count == 16)
        // 24-bit field = 0xFFFFFF sentinel
        #expect(bytes[1] == 0xFF)
        #expect(bytes[2] == 0xFF)
        #expect(bytes[3] == 0xFF)
        // extended: 0x01000000 BE
        #expect(bytes[12] == 0x01)
        #expect(bytes[13] == 0x00)
        #expect(bytes[14] == 0x00)
        #expect(bytes[15] == 0x00)
    }

    @Test("No extended timestamp below boundary")
    func noExtendedTimestamp() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 0xFFFFFE
        )
        #expect(!header.hasExtendedTimestamp)
        let bytes = header.serialize()
        #expect(bytes.count == 12)
    }

    @Test("Fmt 1 with extended timestamp")
    func fmt1ExtendedTimestamp() {
        let header = ChunkHeader(
            format: .sameStream,
            chunkStreamID: 3,
            timestamp: 0x0100_0000,
            messageLength: 10,
            messageTypeID: 1
        )
        let bytes = header.serialize()
        // 1 basic + 7 message + 4 extended = 12
        #expect(bytes.count == 12)
    }

    @Test("Fmt 2 with extended timestamp")
    func fmt2ExtendedTimestamp() {
        let header = ChunkHeader(
            format: .timestampOnly,
            chunkStreamID: 3,
            timestamp: 0x0100_0000
        )
        let bytes = header.serialize()
        // 1 basic + 3 message + 4 extended = 8
        #expect(bytes.count == 8)
    }

    @Test("Fmt 3 with extended timestamp")
    func fmt3ExtendedTimestamp() {
        let header = ChunkHeader(
            format: .continuation,
            chunkStreamID: 3,
            timestamp: 0x0100_0000
        )
        let bytes = header.serialize()
        // 1 basic + 0 message + 4 extended = 5
        #expect(bytes.count == 5)
    }

    // MARK: - Edge Cases

    @Test("Minimum CSID (2)")
    func minimumCSID() {
        let header = ChunkHeader(format: .full, chunkStreamID: 2)
        let bytes = header.serialize()
        #expect(bytes[0] & 0x3F == 2)
    }

    @Test("Maximum CSID (65599)")
    func maximumCSID() {
        let header = ChunkHeader(format: .full, chunkStreamID: 65599)
        let bytes = header.serialize()
        #expect(bytes[0] & 0x3F == 1)
        let adjusted = 65599 - 64
        #expect(bytes[1] == UInt8(adjusted & 0xFF))
        #expect(bytes[2] == UInt8((adjusted >> 8) & 0xFF))
    }

    @Test("Timestamp 0 is valid")
    func timestampZero() {
        let header = ChunkHeader(format: .full, chunkStreamID: 3, timestamp: 0)
        let bytes = header.serialize()
        #expect(bytes[1] == 0)
        #expect(bytes[2] == 0)
        #expect(bytes[3] == 0)
    }

    @Test("Maximum message length (0xFFFFFF)")
    func maxMessageLength() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            messageLength: 0xFFFFFF
        )
        let bytes = header.serialize()
        #expect(bytes[4] == 0xFF)
        #expect(bytes[5] == 0xFF)
        #expect(bytes[6] == 0xFF)
    }

    @Test("Message type ID 0 and 255")
    func messageTypeIDExtremes() {
        let h0 = ChunkHeader(format: .full, chunkStreamID: 3, messageTypeID: 0)
        #expect(h0.serialize()[7] == 0)
        let h255 = ChunkHeader(format: .full, chunkStreamID: 3, messageTypeID: 255)
        #expect(h255.serialize()[7] == 255)
    }

    @Test("Message stream ID 0 (protocol control)")
    func messageStreamIDZero() {
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            messageStreamID: 0
        )
        let bytes = header.serialize()
        #expect(bytes[8] == 0)
        #expect(bytes[9] == 0)
        #expect(bytes[10] == 0)
        #expect(bytes[11] == 0)
    }
}
