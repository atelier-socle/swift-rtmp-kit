// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkHeader — Truncated Input Handling")
struct ChunkHeaderCoverageTests {

    @Test("parse returns nil for truncated fmt0 header bytes")
    func truncatedFmt0ReturnsNil() throws {
        // fmt=0 (bits 7-6 = 00) with csid=3 → basic header 1 byte
        // Then needs 11 bytes for fmt0 header, but we only give 3 bytes
        let bytes: [UInt8] = [0x03, 0x00, 0x01]
        var offset = 0
        let result = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: [:]
        )
        #expect(result == nil)
        // offset should be reset to 0 after failed parse
        #expect(offset == 0)
    }

    @Test("parse returns nil for continuation chunk with truncated extended timestamp")
    func continuationTruncatedExtTimestamp() throws {
        // Create a previous header for CSID 3 with extended timestamp
        var previousHeaders: [UInt32: ChunkHeader] = [:]
        let prev = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 0xFFFFFF,
            messageLength: 10,
            messageTypeID: 1,
            messageStreamID: 0
        )
        previousHeaders[3] = prev

        // fmt=3 (continuation) for CSID 3: basic header = 0xC3
        // With extended timestamp, needs 4 more bytes — give only 2
        let bytes: [UInt8] = [0xC3, 0x01, 0x02]
        var offset = 0
        let result = try ChunkHeader.parse(
            from: bytes, offset: &offset, previousHeaders: previousHeaders
        )
        #expect(result == nil)
        #expect(offset == 0)
    }
}
