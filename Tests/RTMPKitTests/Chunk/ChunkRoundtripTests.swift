// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Chunk Roundtrip — Disassemble → Assemble")
struct ChunkRoundtripTests {

    // MARK: - Single Message Roundtrip

    @Test("Roundtrip small message")
    func roundtripSmall() throws {
        let msg = RTMPMessage(
            typeID: 20, streamID: 1, timestamp: 500,
            payload: Array(repeating: 0xAB, count: 50)
        )
        let result = try roundtrip(msg, chunkStreamID: .command)
        #expect(result.count == 1)
        #expect(result[0] == msg)
    }

    @Test("Roundtrip multi-chunk message")
    func roundtripMultiChunk() throws {
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 1000,
            payload: Array(repeating: 0xCC, count: 500)
        )
        let result = try roundtrip(msg, chunkStreamID: .video, chunkSize: 128)
        #expect(result.count == 1)
        #expect(result[0] == msg)
    }

    @Test("Roundtrip message with extended timestamp")
    func roundtripExtendedTimestamp() throws {
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0x0100_0000,
            payload: [0x01, 0x02, 0x03]
        )
        let result = try roundtrip(msg, chunkStreamID: .command)
        #expect(result.count == 1)
        #expect(result[0] == msg)
    }

    @Test("Roundtrip message at chunk boundary")
    func roundtripAtBoundary() throws {
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xDD, count: 128)
        )
        let result = try roundtrip(msg, chunkStreamID: .video, chunkSize: 128)
        #expect(result.count == 1)
        #expect(result[0] == msg)
    }

    @Test("Roundtrip message with empty payload")
    func roundtripEmptyPayload() throws {
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0,
            payload: []
        )
        let result = try roundtrip(msg, chunkStreamID: .command)
        #expect(result.count == 1)
        #expect(result[0] == msg)
    }

    // MARK: - Multiple Messages

    @Test("Roundtrip multiple sequential messages")
    func roundtripMultipleMessages() throws {
        let msg1 = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0,
            payload: Array(repeating: 0x01, count: 50)
        )
        let msg2 = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 100,
            payload: Array(repeating: 0x02, count: 200)
        )
        let msg3 = RTMPMessage(
            typeID: 8, streamID: 1, timestamp: 200,
            payload: Array(repeating: 0x03, count: 30)
        )
        var disassembler = ChunkDisassembler(chunkSize: 128)
        var allBytes: [UInt8] = []
        allBytes.append(
            contentsOf: disassembler.disassemble(
                message: msg1, chunkStreamID: .command
            ))
        allBytes.append(
            contentsOf: disassembler.disassemble(
                message: msg2, chunkStreamID: .video
            ))
        allBytes.append(
            contentsOf: disassembler.disassemble(
                message: msg3, chunkStreamID: .audio
            ))
        var assembler = ChunkAssembler(chunkSize: 128)
        let messages = try assembler.process(bytes: allBytes)
        #expect(messages.count == 3)
        #expect(messages[0] == msg1)
        #expect(messages[1] == msg2)
        #expect(messages[2] == msg3)
    }

    // MARK: - Interleaved Streams

    @Test("Roundtrip interleaved audio + video")
    func roundtripInterleaved() throws {
        let audio = RTMPMessage(
            typeID: 8, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAA, count: 200)
        )
        let video = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xBB, count: 200)
        )
        var disassembler = ChunkDisassembler(chunkSize: 128)
        let audioBytes = disassembler.disassemble(
            message: audio, chunkStreamID: .audio
        )
        let videoBytes = disassembler.disassemble(
            message: video, chunkStreamID: .video
        )
        // Concatenate (not truly interleaved, but assembler handles both CSIDs)
        var allBytes: [UInt8] = []
        allBytes.append(contentsOf: audioBytes)
        allBytes.append(contentsOf: videoBytes)
        var assembler = ChunkAssembler(chunkSize: 128)
        let messages = try assembler.process(bytes: allBytes)
        #expect(messages.count == 2)
        #expect(messages[0] == audio)
        #expect(messages[1] == video)
    }

    // MARK: - Custom Chunk Sizes

    @Test("Roundtrip with chunk size 1")
    func roundtripChunkSize1() throws {
        let msg = RTMPMessage(
            typeID: 20, streamID: 0, timestamp: 0,
            payload: [0x01, 0x02, 0x03]
        )
        let result = try roundtrip(msg, chunkStreamID: .command, chunkSize: 1)
        #expect(result.count == 1)
        #expect(result[0] == msg)
    }

    @Test("Roundtrip with chunk size 4096")
    func roundtripChunkSize4096() throws {
        let msg = RTMPMessage(
            typeID: 9, streamID: 1, timestamp: 0,
            payload: Array(repeating: 0xAB, count: 5000)
        )
        let result = try roundtrip(msg, chunkStreamID: .video, chunkSize: 4096)
        #expect(result.count == 1)
        #expect(result[0] == msg)
    }

    @Test("Roundtrip preserves payload content exactly")
    func roundtripPayloadIntegrity() throws {
        let payload: [UInt8] = (0..<256).map { UInt8($0) }
        let msg = RTMPMessage(
            typeID: 20, streamID: 1, timestamp: 42,
            payload: payload
        )
        let result = try roundtrip(msg, chunkStreamID: .command, chunkSize: 100)
        #expect(result.count == 1)
        #expect(result[0].payload == payload)
    }

    // MARK: - Helpers

    private func roundtrip(
        _ message: RTMPMessage,
        chunkStreamID: ChunkStreamID,
        chunkSize: UInt32 = 128
    ) throws -> [RTMPMessage] {
        var disassembler = ChunkDisassembler(chunkSize: chunkSize)
        let bytes = disassembler.disassemble(
            message: message, chunkStreamID: chunkStreamID
        )
        var assembler = ChunkAssembler(chunkSize: chunkSize)
        return try assembler.process(bytes: bytes)
    }
}
