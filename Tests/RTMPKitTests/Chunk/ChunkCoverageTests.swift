// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkError — Description Coverage")
struct ChunkErrorDescriptionCoverageTests {

    @Test("invalidChunkStreamID description")
    func invalidChunkStreamIDDescription() {
        let err = ChunkError.invalidChunkStreamID(999)
        #expect(err.description.contains("999"))
    }

    @Test("invalidChunkSize description")
    func invalidChunkSizeDescription() {
        let err = ChunkError.invalidChunkSize(0)
        #expect(err.description.contains("0"))
    }

    @Test("messageLengthExceeded description")
    func messageLengthExceededDescription() {
        let err = ChunkError.messageLengthExceeded(
            expected: 100, received: 200)
        #expect(err.description.contains("100"))
        #expect(err.description.contains("200"))
    }

    @Test("noPreviousHeader description")
    func noPreviousHeaderDescription() {
        let err = ChunkError.noPreviousHeader(chunkStreamID: 6)
        #expect(err.description.contains("6"))
    }
}

@Suite("ChunkHeader — Extended Timestamp Parsing Coverage")
struct ChunkHeaderExtTimestampTests {

    @Test("Fmt 1 with extended timestamp parses correctly")
    func fmt1ExtendedTimestamp() throws {
        // Build a fmt 0 first to establish state
        let h0 = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0, messageLength: 10,
            messageTypeID: 9, messageStreamID: 1)
        var bytes = h0.serialize()
        bytes.append(contentsOf: Array(repeating: 0x01, count: 10))

        // Parse fmt 0 to establish state
        var offset = 0
        var previousHeaders: [UInt32: ChunkHeader] = [:]
        let parsed0 = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: previousHeaders)
        #expect(parsed0 != nil)
        previousHeaders[3] = try #require(parsed0)

        // Now build fmt 1 with extended timestamp (>=0xFFFFFF)
        let h1 = ChunkHeader(
            format: .sameStream, chunkStreamID: 3,
            timestamp: 0x0100_0000, messageLength: 10,
            messageTypeID: 9, messageStreamID: 1)
        var bytes1 = h1.serialize()
        bytes1.append(contentsOf: Array(repeating: 0x02, count: 10))

        var offset1 = 0
        let parsed1 = try ChunkHeader.parse(
            from: bytes1, offset: &offset1, previousHeaders: previousHeaders)
        #expect(parsed1 != nil)
        #expect(parsed1?.timestamp == 0x0100_0000)
    }

    @Test("Fmt 2 with extended timestamp parses correctly")
    func fmt2ExtendedTimestamp() throws {
        // Build fmt 0 first to establish state
        let h0 = ChunkHeader(
            format: .full, chunkStreamID: 4,
            timestamp: 0, messageLength: 5,
            messageTypeID: 9, messageStreamID: 1)
        var previousHeaders: [UInt32: ChunkHeader] = [4: h0]

        // Build fmt 2 with extended timestamp
        let h2 = ChunkHeader(
            format: .timestampOnly, chunkStreamID: 4,
            timestamp: 0x0200_0000)
        let bytes2 = h2.serialize()

        var offset = 0
        let parsed = try ChunkHeader.parse(
            from: bytes2, offset: &offset, previousHeaders: previousHeaders)
        #expect(parsed != nil)
        #expect(parsed?.timestamp == 0x0200_0000)
    }

    @Test("Fmt 3 with extended timestamp from previous header")
    func fmt3ExtendedTimestamp() throws {
        // Previous header has extended timestamp
        let prev = ChunkHeader(
            format: .full, chunkStreamID: 5,
            timestamp: 0x0100_0000, messageLength: 5,
            messageTypeID: 9, messageStreamID: 1)
        var previousHeaders: [UInt32: ChunkHeader] = [5: prev]

        // Build fmt 3 continuation — must carry extended timestamp
        let h3 = ChunkHeader(
            format: .continuation, chunkStreamID: 5,
            timestamp: 0x0100_0000)
        let bytes = h3.serialize()

        var offset = 0
        let parsed = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: previousHeaders)
        #expect(parsed != nil)
        #expect(parsed?.timestamp == 0x0100_0000)
    }

    @Test("Fmt 3 extended timestamp insufficient bytes returns nil")
    func fmt3ExtendedTimestampInsufficient() throws {
        let prev = ChunkHeader(
            format: .full, chunkStreamID: 5,
            timestamp: 0x0100_0000, messageLength: 5,
            messageTypeID: 9, messageStreamID: 1)
        let previousHeaders: [UInt32: ChunkHeader] = [5: prev]

        // Only the basic header byte, no extended timestamp bytes
        let bytes: [UInt8] = [0xC5]  // fmt=3, csid=5
        var offset = 0
        let parsed = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: previousHeaders)
        #expect(parsed == nil)
    }

    @Test("Parse insufficient bytes for basic header returns nil")
    func insufficientBytesBasicHeader() throws {
        let bytes: [UInt8] = []
        var offset = 0
        let parsed = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:])
        #expect(parsed == nil)
    }

    @Test("Fmt 0 with extended timestamp insufficient bytes returns nil")
    func fmt0ExtendedTimestampInsufficient() throws {
        // fmt 0, csid=3, timestamp=0xFFFFFF but no extended timestamp bytes
        var bytes: [UInt8] = [0x03]  // fmt=0, csid=3
        // Timestamp = 0xFFFFFF (sentinel)
        bytes.append(contentsOf: [0xFF, 0xFF, 0xFF])
        // Message length
        bytes.append(contentsOf: [0x00, 0x00, 0x0A])
        // Type ID
        bytes.append(0x09)
        // Stream ID (LE)
        bytes.append(contentsOf: [0x01, 0x00, 0x00, 0x00])
        // No extended timestamp bytes follow

        var offset = 0
        let parsed = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:])
        #expect(parsed == nil)
    }

    @Test("Two-byte CSID basic header (CSID 64-319)")
    func twoByteCsidBasicHeader() throws {
        let h = ChunkHeader(
            format: .full, chunkStreamID: 100,
            timestamp: 0, messageLength: 5,
            messageTypeID: 9, messageStreamID: 1)
        let bytes = h.serialize()
        var offset = 0
        let parsed = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:])
        #expect(parsed?.chunkStreamID == 100)
    }

    @Test("Three-byte CSID basic header (CSID 320+)")
    func threeByteCsidBasicHeader() throws {
        let h = ChunkHeader(
            format: .full, chunkStreamID: 500,
            timestamp: 0, messageLength: 5,
            messageTypeID: 9, messageStreamID: 1)
        let bytes = h.serialize()
        var offset = 0
        let parsed = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:])
        #expect(parsed?.chunkStreamID == 500)
    }
}
