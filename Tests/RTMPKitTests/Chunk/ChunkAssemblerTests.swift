// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkAssembler — Basic")
struct ChunkAssemblerBasicTests {

    // MARK: - Single Chunk Messages

    @Test("Single chunk message (payload <= chunk size)")
    func singleChunk() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let payload: [UInt8] = Array(repeating: 0xAB, count: 50)
        let bytes = makeChunk(
            header: .init(
                format: .full, chunkStreamID: 3,
                timestamp: 0, messageLength: 50,
                messageTypeID: 20, messageStreamID: 1),
            payload: payload
        )
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 1)
        #expect(messages[0].typeID == 20)
        #expect(messages[0].streamID == 1)
        #expect(messages[0].timestamp == 0)
        #expect(messages[0].payload == payload)
    }

    @Test("Message exactly at chunk size boundary")
    func exactChunkSize() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let payload: [UInt8] = Array(repeating: 0xAB, count: 128)
        let bytes = makeChunk(
            header: .init(
                format: .full, chunkStreamID: 3,
                timestamp: 0, messageLength: 128,
                messageTypeID: 9, messageStreamID: 1),
            payload: payload
        )
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 1)
        #expect(messages[0].payload.count == 128)
    }

    // MARK: - Multi-Chunk Assembly

    @Test("Two-chunk message assembly")
    func twoChunks() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let payload: [UInt8] = Array(0..<200).map { UInt8($0 % 256) }
        var bytes: [UInt8] = []
        let header = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0, messageLength: 200,
            messageTypeID: 9, messageStreamID: 1
        )
        bytes.append(contentsOf: header.serialize())
        bytes.append(contentsOf: payload[0..<128])
        bytes.append(0xC3)  // fmt=3, csid=3
        bytes.append(contentsOf: payload[128..<200])
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 1)
        #expect(messages[0].payload == payload)
    }

    @Test("Four-chunk message assembly")
    func fourChunks() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let payload: [UInt8] = Array(repeating: 0xCC, count: 500)
        var bytes: [UInt8] = []
        let header = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0, messageLength: 500,
            messageTypeID: 9, messageStreamID: 1
        )
        bytes.append(contentsOf: header.serialize())
        bytes.append(contentsOf: payload[0..<128])
        bytes.append(0xC3)
        bytes.append(contentsOf: payload[128..<256])
        bytes.append(0xC3)
        bytes.append(contentsOf: payload[256..<384])
        bytes.append(0xC3)
        bytes.append(contentsOf: payload[384..<500])
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 1)
        #expect(messages[0].payload == payload)
    }

    @Test("Message one byte over chunk size")
    func oneByteOver() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let payload: [UInt8] = Array(repeating: 0xDD, count: 129)
        var bytes: [UInt8] = []
        let header = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0, messageLength: 129,
            messageTypeID: 9, messageStreamID: 1
        )
        bytes.append(contentsOf: header.serialize())
        bytes.append(contentsOf: payload[0..<128])
        bytes.append(0xC3)
        bytes.append(contentsOf: payload[128..<129])
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 1)
        #expect(messages[0].payload == payload)
    }

    // MARK: - Multiplexing

    @Test("Two interleaved streams")
    func twoInterleavedStreams() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let audioPayload: [UInt8] = Array(repeating: 0xAA, count: 100)
        let videoPayload: [UInt8] = Array(repeating: 0xBB, count: 100)
        var bytes: [UInt8] = []
        bytes.append(
            contentsOf: makeChunk(
                header: .init(
                    format: .full, chunkStreamID: 4,
                    timestamp: 0, messageLength: 100,
                    messageTypeID: 8, messageStreamID: 1),
                payload: audioPayload
            ))
        bytes.append(
            contentsOf: makeChunk(
                header: .init(
                    format: .full, chunkStreamID: 6,
                    timestamp: 0, messageLength: 100,
                    messageTypeID: 9, messageStreamID: 1),
                payload: videoPayload
            ))
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 2)
        #expect(messages[0].typeID == 8)
        #expect(messages[0].payload == audioPayload)
        #expect(messages[1].typeID == 9)
        #expect(messages[1].payload == videoPayload)
    }

    @Test("Interleaved multi-chunk streams")
    func interleavedMultiChunk() throws {
        var assembler = ChunkAssembler(chunkSize: 64)
        let audioPayload: [UInt8] = Array(repeating: 0xAA, count: 100)
        let videoPayload: [UInt8] = Array(repeating: 0xBB, count: 100)
        var bytes: [UInt8] = []
        let audioHeader = ChunkHeader(
            format: .full, chunkStreamID: 4,
            timestamp: 0, messageLength: 100,
            messageTypeID: 8, messageStreamID: 1
        )
        bytes.append(contentsOf: audioHeader.serialize())
        bytes.append(contentsOf: audioPayload[0..<64])
        let videoHeader = ChunkHeader(
            format: .full, chunkStreamID: 6,
            timestamp: 0, messageLength: 100,
            messageTypeID: 9, messageStreamID: 1
        )
        bytes.append(contentsOf: videoHeader.serialize())
        bytes.append(contentsOf: videoPayload[0..<64])
        bytes.append(0xC4)  // fmt=3, csid=4
        bytes.append(contentsOf: audioPayload[64..<100])
        bytes.append(0xC6)  // fmt=3, csid=6
        bytes.append(contentsOf: videoPayload[64..<100])
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 2)
        #expect(messages[0].payload == audioPayload)
        #expect(messages[1].payload == videoPayload)
    }

    // MARK: - Chunk Size Changes

    @Test("Default chunk size 128")
    func defaultChunkSize() {
        let assembler = ChunkAssembler()
        #expect(assembler.chunkSize == 128)
    }

    @Test("setChunkSize changes assembly behavior")
    func changeChunkSize() throws {
        var assembler = ChunkAssembler(chunkSize: 64)
        assembler.setChunkSize(256)
        let payload: [UInt8] = Array(repeating: 0xAB, count: 200)
        let bytes = makeChunk(
            header: .init(
                format: .full, chunkStreamID: 3,
                timestamp: 0, messageLength: 200,
                messageTypeID: 20, messageStreamID: 1),
            payload: payload
        )
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 1)
        #expect(messages[0].payload.count == 200)
    }

    // MARK: - Helpers

    private func makeChunk(header: ChunkHeader, payload: [UInt8]) -> [UInt8] {
        var bytes = header.serialize()
        bytes.append(contentsOf: payload)
        return bytes
    }
}

@Suite("ChunkAssembler — Partial Data")
struct ChunkAssemblerPartialTests {

    // MARK: - Partial Data Handling

    @Test("Partial header buffers bytes")
    func partialHeader() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let partial: [UInt8] = [0x03, 0x00, 0x00, 0x00, 0x00]
        let messages = try assembler.process(bytes: partial)
        #expect(messages.isEmpty)
    }

    @Test("Partial payload buffers bytes")
    func partialPayload() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let header = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0, messageLength: 100,
            messageTypeID: 20, messageStreamID: 1
        )
        var bytes = header.serialize()
        bytes.append(contentsOf: Array(repeating: 0xAB, count: 50))
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.isEmpty)
    }

    @Test("Complete message after feeding remaining bytes")
    func completeAfterPartial() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let payload: [UInt8] = Array(repeating: 0xAB, count: 100)
        let header = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0, messageLength: 100,
            messageTypeID: 20, messageStreamID: 1
        )
        var part1 = header.serialize()
        part1.append(contentsOf: payload[0..<50])
        var messages = try assembler.process(bytes: part1)
        #expect(messages.isEmpty)
        let part2 = Array(payload[50..<100])
        messages = try assembler.process(bytes: part2)
        #expect(messages.count == 1)
        #expect(messages[0].payload == payload)
    }

    // MARK: - Error Cases

    @Test("Fmt 1 on CSID without prior state throws")
    func fmt1NoPriorState() {
        var assembler = ChunkAssembler(chunkSize: 128)
        let bytes: [UInt8] = [
            0x43, 0x00, 0x00, 0x21,
            0x00, 0x00, 0x80, 0x09, 0x00
        ]
        #expect(throws: ChunkError.self) {
            try assembler.process(bytes: bytes)
        }
    }

    @Test("Fmt 3 on CSID without prior state throws")
    func fmt3NoPriorState() {
        var assembler = ChunkAssembler(chunkSize: 128)
        #expect(throws: ChunkError.self) {
            try assembler.process(bytes: [0xC3])
        }
    }

    // MARK: - Reset

    @Test("Reset clears all state")
    func resetClearsState() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let payload: [UInt8] = Array(repeating: 0xAB, count: 50)
        let bytes = makeChunk(
            header: .init(
                format: .full, chunkStreamID: 3,
                timestamp: 0, messageLength: 50,
                messageTypeID: 20, messageStreamID: 1),
            payload: payload
        )
        _ = try assembler.process(bytes: bytes)
        assembler.reset()
        #expect(throws: ChunkError.self) {
            try assembler.process(bytes: [0xC3])
        }
    }

    // MARK: - Helpers

    private func makeChunk(header: ChunkHeader, payload: [UInt8]) -> [UInt8] {
        var bytes = header.serialize()
        bytes.append(contentsOf: payload)
        return bytes
    }
}

@Suite("ChunkAssembler — Extended Timestamp")
struct ChunkAssemblerExtendedTests {

    @Test("Assembly with extended timestamp")
    func extendedTimestamp() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let payload: [UInt8] = Array(repeating: 0xAB, count: 10)
        let header = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0x0100_0000, messageLength: 10,
            messageTypeID: 20, messageStreamID: 1
        )
        var bytes = header.serialize()
        bytes.append(contentsOf: payload)
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 1)
        #expect(messages[0].timestamp == 0x0100_0000)
    }

    @Test("Fmt 3 continuation inherits extended timestamp")
    func fmt3InheritsExtended() throws {
        var assembler = ChunkAssembler(chunkSize: 4)
        let payload: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
        let header = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: 0x0100_0000, messageLength: 5,
            messageTypeID: 20, messageStreamID: 1
        )
        var bytes = header.serialize()
        bytes.append(contentsOf: payload[0..<4])
        let contHeader = ChunkHeader(
            format: .continuation, chunkStreamID: 3,
            timestamp: 0x0100_0000
        )
        bytes.append(contentsOf: contHeader.serialize())
        bytes.append(contentsOf: payload[4..<5])
        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 1)
        #expect(messages[0].payload == payload)
        #expect(messages[0].timestamp == 0x0100_0000)
    }
}
