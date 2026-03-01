// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkHeader — Parsing")
struct ChunkHeaderParseTests {

    // MARK: - Fmt 0 Parsing

    @Test("Parse fmt 0 from known bytes")
    func parseFmt0() throws {
        let bytes: [UInt8] = [
            0x03,  // fmt=0, csid=3
            0x00, 0x03, 0xE8,  // timestamp
            0x00, 0x01, 0x00,  // message length
            0x14,  // type ID
            0x01, 0x00, 0x00, 0x00  // stream ID (LE)
        ]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:]
        )
        #expect(header != nil)
        #expect(header?.format == .full)
        #expect(header?.chunkStreamID == 3)
        #expect(header?.timestamp == 1000)
        #expect(header?.messageLength == 256)
        #expect(header?.messageTypeID == 0x14)
        #expect(header?.messageStreamID == 1)
        #expect(offset == 12)
    }

    @Test("Parse fmt 0 verifies message stream ID is little-endian")
    func parseFmt0LEStreamID() throws {
        let bytes: [UInt8] = [
            0x03,
            0x00, 0x00, 0x00,
            0x00, 0x00, 0x01,
            0x14,
            0x04, 0x03, 0x02, 0x01  // LE: 0x01020304
        ]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:]
        )
        #expect(header?.messageStreamID == 0x0102_0304)
    }

    // MARK: - Fmt 1 Parsing

    @Test("Parse fmt 1 from known bytes")
    func parseFmt1() throws {
        let prevHeader = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 1000, messageLength: 100,
            messageTypeID: 20, messageStreamID: 1
        )
        let bytes: [UInt8] = [
            0x43,  // fmt=1, csid=3
            0x00, 0x00, 0x21,  // timestamp delta = 33
            0x00, 0x00, 0x80,  // message length = 128
            0x09  // type ID = 9
        ]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [3: prevHeader]
        )
        #expect(header?.format == .sameStream)
        #expect(header?.timestamp == 33)
        #expect(header?.messageLength == 128)
        #expect(header?.messageTypeID == 9)
        #expect(header?.messageStreamID == 1)
        #expect(offset == 8)
    }

    // MARK: - Fmt 2 Parsing

    @Test("Parse fmt 2 from known bytes")
    func parseFmt2() throws {
        let prevHeader = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 1000, messageLength: 100,
            messageTypeID: 20, messageStreamID: 1
        )
        let bytes: [UInt8] = [
            0x83,  // fmt=2, csid=3
            0x00, 0x00, 0x21  // timestamp delta = 33
        ]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [3: prevHeader]
        )
        #expect(header?.format == .timestampOnly)
        #expect(header?.timestamp == 33)
        #expect(header?.messageLength == 100)
        #expect(header?.messageTypeID == 20)
        #expect(header?.messageStreamID == 1)
        #expect(offset == 4)
    }

    // MARK: - Fmt 3 Parsing

    @Test("Parse fmt 3 from known bytes")
    func parseFmt3() throws {
        let prevHeader = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 1000, messageLength: 100,
            messageTypeID: 20, messageStreamID: 1
        )
        let bytes: [UInt8] = [0xC3]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [3: prevHeader]
        )
        #expect(header?.format == .continuation)
        #expect(header?.timestamp == 1000)
        #expect(header?.messageLength == 100)
        #expect(header?.messageTypeID == 20)
        #expect(header?.messageStreamID == 1)
        #expect(offset == 1)
    }

    // MARK: - Multi-Byte CSID Parsing

    @Test("Parse 2-byte CSID basic header")
    func parse2ByteCSID() throws {
        let bytes: [UInt8] = [
            0x00, 136,  // fmt=0, 2-byte CSID = 136+64 = 200
            0x00, 0x00, 0x00,
            0x00, 0x00, 0x01,
            0x14,
            0x00, 0x00, 0x00, 0x00
        ]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:]
        )
        #expect(header?.chunkStreamID == 200)
    }

    @Test("Parse 3-byte CSID basic header")
    func parse3ByteCSID() throws {
        let adjusted = 1000 - 64
        let bytes: [UInt8] = [
            0x01,  // fmt=0, 3-byte marker
            UInt8(adjusted & 0xFF),
            UInt8((adjusted >> 8) & 0xFF),
            0x00, 0x00, 0x00,
            0x00, 0x00, 0x01,
            0x14,
            0x00, 0x00, 0x00, 0x00
        ]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:]
        )
        #expect(header?.chunkStreamID == 1000)
    }

    // MARK: - Extended Timestamp Parsing

    @Test("Parse extended timestamp in fmt 0")
    func parseExtendedTimestampFmt0() throws {
        let bytes: [UInt8] = [
            0x03, 0xFF, 0xFF, 0xFF,
            0x00, 0x00, 0x01, 0x14,
            0x00, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x00, 0x00  // extended = 0x01000000
        ]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:]
        )
        #expect(header?.timestamp == 0x0100_0000)
        #expect(offset == 16)
    }

    @Test("Parse fmt 3 inherits extended timestamp")
    func parseFmt3InheritsExtended() throws {
        let prevHeader = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0x0100_0000, messageLength: 100,
            messageTypeID: 20, messageStreamID: 1
        )
        let bytes: [UInt8] = [
            0xC3,
            0x01, 0x00, 0x00, 0x00
        ]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [3: prevHeader]
        )
        #expect(header?.timestamp == 0x0100_0000)
        #expect(offset == 5)
    }

    // MARK: - Error Cases

    @Test("Fmt 1 without previous header throws")
    func fmt1NoPrevious() {
        let bytes: [UInt8] = [0x43, 0x00, 0x00, 0x21, 0x00, 0x00, 0x80, 0x09]
        var offset = 0
        #expect(throws: ChunkError.self) {
            try ChunkHeader.parse(
                from: bytes, offset: &offset, previousHeaders: [:]
            )
        }
    }

    @Test("Fmt 2 without previous header throws")
    func fmt2NoPrevious() {
        let bytes: [UInt8] = [0x83, 0x00, 0x00, 0x21]
        var offset = 0
        #expect(throws: ChunkError.self) {
            try ChunkHeader.parse(
                from: bytes, offset: &offset, previousHeaders: [:]
            )
        }
    }

    @Test("Fmt 3 without previous header throws")
    func fmt3NoPrevious() {
        var offset = 0
        #expect(throws: ChunkError.self) {
            try ChunkHeader.parse(
                from: [0xC3], offset: &offset, previousHeaders: [:]
            )
        }
    }

    @Test("Insufficient bytes returns nil without advancing offset")
    func insufficientBytes() throws {
        let bytes: [UInt8] = [0x03, 0x00, 0x00, 0x00, 0x00]
        var offset = 0
        let header = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:]
        )
        #expect(header == nil)
        #expect(offset == 0)
    }

    @Test("Empty bytes returns nil")
    func emptyBytes() throws {
        var offset = 0
        let header = try ChunkHeader.parse(
            from: [], offset: &offset, previousHeaders: [:]
        )
        #expect(header == nil)
    }
}

@Suite("ChunkHeader — Roundtrip")
struct ChunkHeaderRoundtripTests {

    @Test("Roundtrip fmt 0 full header")
    func roundtripFmt0() throws {
        let original = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 1000, messageLength: 256,
            messageTypeID: 20, messageStreamID: 1
        )
        let parsed = try parseRoundtrip(original)
        #expect(parsed?.format == original.format)
        #expect(parsed?.chunkStreamID == original.chunkStreamID)
        #expect(parsed?.timestamp == original.timestamp)
        #expect(parsed?.messageLength == original.messageLength)
        #expect(parsed?.messageTypeID == original.messageTypeID)
        #expect(parsed?.messageStreamID == original.messageStreamID)
    }

    @Test("Roundtrip fmt 0 with extended timestamp")
    func roundtripFmt0Extended() throws {
        let original = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0x0200_0000, messageLength: 100,
            messageTypeID: 9, messageStreamID: 1
        )
        let parsed = try parseRoundtrip(original)
        #expect(parsed?.timestamp == 0x0200_0000)
    }

    @Test("Roundtrip fmt 0 with 2-byte CSID")
    func roundtripFmt0CSID2Byte() throws {
        let original = ChunkHeader(
            format: .full, chunkStreamID: 200,
            timestamp: 500, messageLength: 50,
            messageTypeID: 8, messageStreamID: 0
        )
        let parsed = try parseRoundtrip(original)
        #expect(parsed?.chunkStreamID == 200)
    }

    @Test("Roundtrip fmt 0 with 3-byte CSID")
    func roundtripFmt0CSID3Byte() throws {
        let original = ChunkHeader(
            format: .full, chunkStreamID: 1000,
            timestamp: 500, messageLength: 50,
            messageTypeID: 8, messageStreamID: 0
        )
        let parsed = try parseRoundtrip(original)
        #expect(parsed?.chunkStreamID == 1000)
    }

    private func parseRoundtrip(_ header: ChunkHeader) throws -> ChunkHeader? {
        let bytes = header.serialize()
        var offset = 0
        return try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:]
        )
    }
}
