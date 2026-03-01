// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkDisassembler — Basic")
struct ChunkDisassemblerBasicTests {

    // MARK: - Single Chunk Messages

    @Test("Small message fits in one chunk")
    func singleChunk() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAB, count: 50)
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // 1 basic + 11 message header + 50 payload
        #expect(bytes.count == 62)
    }

    @Test("Message exactly at chunk size boundary")
    func exactChunkSize() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAB, count: 128)
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // 1 basic + 11 message + 128 payload = 140 (single chunk)
        #expect(bytes.count == 140)
    }

    @Test("Message one byte over chunk size produces 2 chunks")
    func oneByteOver() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAB, count: 129)
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // chunk 1: 1 basic + 11 message + 128 payload = 140
        // chunk 2: 1 basic (fmt3) + 1 payload = 2
        #expect(bytes.count == 142)
    }

    // MARK: - Multi-Chunk Messages

    @Test("Large message produces fmt 0 + fmt 3 chunks")
    func multiChunk2x() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAB, count: 256)
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // chunk 1: 12 header + 128 payload
        // chunk 2: 1 header + 128 payload
        #expect(bytes.count == 12 + 128 + 1 + 128)
    }

    @Test("Large message produces fmt 0 + 4x fmt 3")
    func multiChunk5x() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAB, count: 640)
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // 1 fmt0 header (12) + 128 + 4 * (1 fmt3 header + 128) = 12 + 128 + 516
        #expect(bytes.count == 12 + 128 + 4 * (1 + 128))
    }

    // MARK: - First Chunk Format

    @Test("First chunk uses fmt 0")
    func firstChunkFmt0() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 1, timestamp: 0,
            payload: [0x01]
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        #expect(bytes[0] >> 6 == 0)  // fmt = 0
    }

    @Test("Continuation chunks use fmt 3")
    func continuationFmt3() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAB, count: 256)
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // fmt 3 basic header at offset 12 + 128 = 140
        #expect(bytes[140] >> 6 == 3)  // fmt = 3
    }

    // MARK: - Chunk Size

    @Test("Custom chunk size 4096")
    func customChunkSize4096() {
        var disassembler = ChunkDisassembler(chunkSize: 4096)
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAB, count: 4096)
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // Single chunk: 12 + 4096
        #expect(bytes.count == 12 + 4096)
    }

    @Test("Very small chunk size (1) produces many chunks")
    func tinyChunkSize() {
        var disassembler = ChunkDisassembler(chunkSize: 1)
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: [0x01, 0x02, 0x03]
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // chunk 1: 12 header + 1 payload = 13
        // chunk 2: 1 header + 1 payload = 2
        // chunk 3: 1 header + 1 payload = 2
        #expect(bytes.count == 17)
    }

    @Test("setChunkSize changes subsequent behavior")
    func setChunkSize() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        disassembler.setChunkSize(4096)
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAB, count: 256)
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // Single chunk with 4096 chunk size
        #expect(bytes.count == 12 + 256)
    }
}

@Suite("ChunkDisassembler — Byte Order")
struct ChunkDisassemblerByteOrderTests {

    // MARK: - Byte Order Verification

    @Test("Timestamps are big-endian in output")
    func timestampBigEndian() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0x010203,
            payload: [0x01]
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        #expect(bytes[1] == 0x01)
        #expect(bytes[2] == 0x02)
        #expect(bytes[3] == 0x03)
    }

    @Test("Message length is big-endian in output")
    func messageLengthBigEndian() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0,
            payload: Array(repeating: 0, count: 0x010203)
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        #expect(bytes[4] == 0x01)
        #expect(bytes[5] == 0x02)
        #expect(bytes[6] == 0x03)
    }

    @Test("Message stream ID is little-endian in fmt 0")
    func messageStreamIDLittleEndian() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 0x0102_0304, timestamp: 0,
            payload: [0x01]
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        #expect(bytes[8] == 0x04)  // LSB first
        #expect(bytes[9] == 0x03)
        #expect(bytes[10] == 0x02)
        #expect(bytes[11] == 0x01)  // MSB last
    }

    @Test("Extended timestamp is big-endian in output")
    func extendedTimestampBigEndian() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0x0102_0304,
            payload: [0x01]
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // Extended timestamp after 11-byte message header
        #expect(bytes[1] == 0xFF)  // sentinel
        #expect(bytes[2] == 0xFF)
        #expect(bytes[3] == 0xFF)
        // Extended timestamp at offset 12
        #expect(bytes[12] == 0x01)
        #expect(bytes[13] == 0x02)
        #expect(bytes[14] == 0x03)
        #expect(bytes[15] == 0x04)
    }

    // MARK: - Extended Timestamp

    @Test("Timestamp below 0xFFFFFF has no extended timestamp")
    func noExtendedTimestamp() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0xFFFFFE,
            payload: [0x01]
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        #expect(bytes.count == 13)  // 12 header + 1 payload
    }

    @Test("Timestamp at 0xFFFFFF triggers extended timestamp")
    func extendedAtBoundary() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0xFFFFFF,
            payload: [0x01]
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        #expect(bytes.count == 17)  // 12 + 4 extended + 1 payload
    }

    @Test("Fmt 3 continuation with extended timestamp")
    func fmt3ContinuationExtended() {
        var disassembler = ChunkDisassembler(chunkSize: 4)
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0x0100_0000,
            payload: [0x01, 0x02, 0x03, 0x04, 0x05]
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // chunk 1: 1 basic + 11 msg + 4 ext + 4 payload = 20
        // chunk 2: 1 basic + 4 ext + 1 payload = 6
        #expect(bytes.count == 26)
    }

    // MARK: - Reset

    @Test("Reset clears state")
    func resetState() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 1, timestamp: 0,
            payload: [0x01]
        )
        _ = disassembler.disassemble(message: msg, chunkStreamID: .command)
        disassembler.reset()
        // After reset, first message should still use fmt 0
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        #expect(bytes[0] >> 6 == 0)
    }

    // MARK: - Empty Payload

    @Test("Message with empty payload")
    func emptyPayload() {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0,
            payload: []
        )
        let bytes = disassembler.disassemble(message: msg, chunkStreamID: .command)
        // Just the header, no payload
        #expect(bytes.count == 12)
    }
}
