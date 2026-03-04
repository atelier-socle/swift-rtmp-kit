// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkStream Showcase", .timeLimit(.minutes(1)))
struct ChunkStreamShowcaseTests {

    @Test("Multiplex audio (CSID 4) and video (CSID 6) at 4096 chunk size")
    func multiplexAudioVideo() throws {
        let chunkSize: UInt32 = 4096
        var disassembler = ChunkDisassembler(chunkSize: chunkSize)
        var assembler = ChunkAssembler(chunkSize: chunkSize)

        let audioPayload: [UInt8] = Array(repeating: 0xAA, count: 200)
        let videoPayload: [UInt8] = Array(repeating: 0xBB, count: 5000)

        let audioMsg = RTMPMessage(
            typeID: RTMPMessage.typeIDAudio, streamID: 1,
            timestamp: 0, payload: audioPayload)
        let videoMsg = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 0, payload: videoPayload)

        let audioChunks = disassembler.disassemble(
            message: audioMsg, chunkStreamID: .audio)
        let videoChunks = disassembler.disassemble(
            message: videoMsg, chunkStreamID: .video)

        // Interleave: audio then video
        var combined: [UInt8] = []
        combined.append(contentsOf: audioChunks)
        combined.append(contentsOf: videoChunks)

        let messages = try assembler.process(bytes: combined)
        #expect(messages.count == 2)

        let audio = messages.first { $0.typeID == RTMPMessage.typeIDAudio }
        let video = messages.first { $0.typeID == RTMPMessage.typeIDVideo }
        #expect(audio?.payload == audioPayload)
        #expect(video?.payload == videoPayload)
    }

    @Test("Chunk size change mid-stream")
    func chunkSizeChangeMidStream() throws {
        // Start with chunk size 128
        var disassembler = ChunkDisassembler(chunkSize: 128)
        var assembler = ChunkAssembler(chunkSize: 128)

        // First message at 128 chunk size
        let payload1: [UInt8] = Array(repeating: 0xAA, count: 300)
        let msg1 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 0, payload: payload1)
        let chunks1 = disassembler.disassemble(
            message: msg1, chunkStreamID: .video)
        let messages1 = try assembler.process(bytes: chunks1)
        #expect(messages1.count == 1)
        #expect(messages1[0].payload == payload1)

        // Change chunk size to 4096
        disassembler.setChunkSize(4096)
        assembler.setChunkSize(4096)

        // Second message at 4096 chunk size (fits in 1 chunk)
        let payload2: [UInt8] = Array(repeating: 0xBB, count: 3000)
        let msg2 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 33, payload: payload2)
        let chunks2 = disassembler.disassemble(
            message: msg2, chunkStreamID: .video)
        let messages2 = try assembler.process(bytes: chunks2)
        #expect(messages2.count == 1)
        #expect(messages2[0].payload == payload2)
    }

    @Test("Very large message (1MB payload)")
    func veryLargeMessage() throws {
        let chunkSize: UInt32 = 4096
        var disassembler = ChunkDisassembler(chunkSize: chunkSize)
        var assembler = ChunkAssembler(chunkSize: chunkSize)

        let payload: [UInt8] = (0..<1_048_576).map { UInt8($0 % 256) }
        let msg = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 0, payload: payload)

        let chunks = disassembler.disassemble(
            message: msg, chunkStreamID: .video)
        let messages = try assembler.process(bytes: chunks)

        #expect(messages.count == 1)
        #expect(messages[0].payload.count == 1_048_576)
        #expect(messages[0].payload == payload)
    }

    @Test("Abort clears partial assembly state")
    func abortClearsPartialState() throws {
        // Verify the assembler can handle abort by resetting CSID state
        var assembler = ChunkAssembler(chunkSize: 4096)
        var disassembler = ChunkDisassembler(chunkSize: 4096)

        // Send a complete message on CSID 6 — establishes stream state
        let payload1: [UInt8] = Array(repeating: 0xAA, count: 100)
        let msg1 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 0, payload: payload1)
        let chunks1 = disassembler.disassemble(
            message: msg1, chunkStreamID: .video)
        let msgs1 = try assembler.process(bytes: chunks1)
        #expect(msgs1.count == 1)

        // Send an abort message for CSID 6 on the protocol control stream
        let abortPayload = RTMPControlMessage.abort(chunkStreamID: 6).encode()
        var abortDis = ChunkDisassembler(chunkSize: 4096)
        let abortMsg = RTMPMessage(
            typeID: RTMPMessage.typeIDAbort, streamID: 0,
            timestamp: 0, payload: abortPayload)
        let abortChunks = abortDis.disassemble(
            message: abortMsg, chunkStreamID: .protocolControl)
        let abortMsgs = try assembler.process(bytes: abortChunks)
        #expect(abortMsgs.count == 1)
        #expect(abortMsgs[0].typeID == RTMPMessage.typeIDAbort)

        // After abort, new messages on CSID 6 still work
        var dis2 = ChunkDisassembler(chunkSize: 4096)
        let payload2: [UInt8] = Array(repeating: 0xCC, count: 50)
        let msg2 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 33, payload: payload2)
        let chunks2 = dis2.disassemble(
            message: msg2, chunkStreamID: .video)
        let msgs2 = try assembler.process(bytes: chunks2)
        #expect(msgs2.count == 1)
        #expect(msgs2[0].payload == payload2)
    }

    @Test("Maximum chunk size (0x7FFFFFFF)")
    func maximumChunkSize() throws {
        let maxChunkSize: UInt32 = 0x7FFF_FFFF
        var disassembler = ChunkDisassembler(chunkSize: maxChunkSize)
        var assembler = ChunkAssembler(chunkSize: maxChunkSize)

        // A small message should fit in one chunk with max chunk size
        let payload: [UInt8] = Array(repeating: 0xDD, count: 100)
        let msg = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 0, payload: payload)

        let chunks = disassembler.disassemble(
            message: msg, chunkStreamID: .video)
        let messages = try assembler.process(bytes: chunks)
        #expect(messages.count == 1)
        #expect(messages[0].payload == payload)
    }

    @Test("Extended timestamp on fmt 0")
    func extendedTimestampFmt0() {
        let timestamp: UInt32 = 0x0100_0000  // > 0xFFFFFF
        let header = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: timestamp, messageLength: 10,
            messageTypeID: 20, messageStreamID: 1)
        let serialized = header.serialize()

        // The 24-bit timestamp field should be 0xFFFFFF (sentinel)
        // followed by 4-byte extended timestamp
        #expect(header.hasExtendedTimestamp)

        // Verify roundtrip
        var offset = 0
        let parsed = try? ChunkHeader.parse(
            from: serialized, offset: &offset,
            previousHeaders: [:])
        #expect(parsed?.timestamp == timestamp)
    }

    @Test("Extended timestamp on fmt 3 continuation")
    func extendedTimestampFmt3() throws {
        var assembler = ChunkAssembler(chunkSize: 128)
        let timestamp: UInt32 = 0x0200_0000  // extended timestamp

        let payload: [UInt8] = Array(repeating: 0xEE, count: 200)
        let header = ChunkHeader(
            format: .full, chunkStreamID: 3,
            timestamp: timestamp, messageLength: 200,
            messageTypeID: 9, messageStreamID: 1)

        var bytes = header.serialize()
        bytes.append(contentsOf: payload[0..<128])

        // fmt 3 continuation — must also carry extended timestamp
        let contHeader = ChunkHeader(
            format: .continuation, chunkStreamID: 3,
            timestamp: timestamp)
        bytes.append(contentsOf: contHeader.serialize())
        bytes.append(contentsOf: payload[128..<200])

        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 1)
        #expect(messages[0].timestamp == timestamp)
        #expect(messages[0].payload == payload)
    }

    @Test("All four fmt formats used during assembly")
    func allFourFmtFormats() throws {
        var assembler = ChunkAssembler(chunkSize: 128)

        // Manually construct chunks with all four fmt formats
        // fmt 0 (full header) — first message on CSID 6
        let header0 = ChunkHeader(
            format: .full, chunkStreamID: 6,
            timestamp: 0, messageLength: 10,
            messageTypeID: RTMPMessage.typeIDVideo, messageStreamID: 1)
        var bytes: [UInt8] = header0.serialize()
        bytes.append(contentsOf: Array(repeating: 0x01, count: 10))

        // fmt 1 (same stream ID) — second message, different timestamp
        let header1 = ChunkHeader(
            format: .sameStream, chunkStreamID: 6,
            timestamp: 40, messageLength: 10,
            messageTypeID: RTMPMessage.typeIDVideo, messageStreamID: 1)
        bytes.append(contentsOf: header1.serialize())
        bytes.append(contentsOf: Array(repeating: 0x02, count: 10))

        // fmt 2 (timestamp only) — third message, same type+length
        let header2 = ChunkHeader(
            format: .timestampOnly, chunkStreamID: 6,
            timestamp: 40, messageLength: 10,
            messageTypeID: RTMPMessage.typeIDVideo, messageStreamID: 1)
        bytes.append(contentsOf: header2.serialize())
        bytes.append(contentsOf: Array(repeating: 0x03, count: 10))

        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 3)
        #expect(messages[0].payload == Array(repeating: 0x01, count: 10))
        #expect(messages[1].payload == Array(repeating: 0x02, count: 10))
        #expect(messages[2].payload == Array(repeating: 0x03, count: 10))
        #expect(messages[0].timestamp == 0)
        // fmt 1/2 timestamps are deltas — assembler stores the delta value
        #expect(messages[1].timestamp == 40)
        #expect(messages[2].timestamp == 40)
    }

    @Test("Timestamp delta progression via fmt 1 headers")
    func timestampDeltaProgression() throws {
        var assembler = ChunkAssembler(chunkSize: 4096)

        // Build messages with fmt 1 (sameStream) using timestamp deltas
        // First message: fmt 0 with timestamp 0
        let h0 = ChunkHeader(
            format: .full, chunkStreamID: 6,
            timestamp: 0, messageLength: 1,
            messageTypeID: RTMPMessage.typeIDVideo, messageStreamID: 1)

        // Subsequent: fmt 1 with delta=40
        let h1 = ChunkHeader(
            format: .sameStream, chunkStreamID: 6,
            timestamp: 40, messageLength: 1,
            messageTypeID: RTMPMessage.typeIDVideo, messageStreamID: 1)
        let h2 = ChunkHeader(
            format: .sameStream, chunkStreamID: 6,
            timestamp: 40, messageLength: 1,
            messageTypeID: RTMPMessage.typeIDVideo, messageStreamID: 1)
        let h3 = ChunkHeader(
            format: .sameStream, chunkStreamID: 6,
            timestamp: 40, messageLength: 1,
            messageTypeID: RTMPMessage.typeIDVideo, messageStreamID: 1)

        var bytes: [UInt8] = []
        bytes.append(contentsOf: h0.serialize())
        bytes.append(0x00)  // payload
        bytes.append(contentsOf: h1.serialize())
        bytes.append(0x01)
        bytes.append(contentsOf: h2.serialize())
        bytes.append(0x02)
        bytes.append(contentsOf: h3.serialize())
        bytes.append(0x03)

        let messages = try assembler.process(bytes: bytes)
        #expect(messages.count == 4)
        #expect(messages[0].timestamp == 0)
        // fmt 1 stores delta values as timestamp — not accumulated
        #expect(messages[1].timestamp == 40)
        #expect(messages[2].timestamp == 40)
        #expect(messages[3].timestamp == 40)
    }

    @Test("Message with exactly chunk size bytes")
    func exactlyChunkSize() throws {
        let chunkSize: UInt32 = 4096
        var disassembler = ChunkDisassembler(chunkSize: chunkSize)
        var assembler = ChunkAssembler(chunkSize: chunkSize)

        let payload: [UInt8] = Array(repeating: 0xFF, count: Int(chunkSize))
        let msg = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 0, payload: payload)

        let chunks = disassembler.disassemble(
            message: msg, chunkStreamID: .video)
        let messages = try assembler.process(bytes: chunks)
        #expect(messages.count == 1)
        #expect(messages[0].payload.count == Int(chunkSize))
    }

    @Test("Three concurrent CSID streams interleaved")
    func threeConcurrentStreams() throws {
        let chunkSize: UInt32 = 4096
        var disassembler = ChunkDisassembler(chunkSize: chunkSize)
        var assembler = ChunkAssembler(chunkSize: chunkSize)

        let audioPayload: [UInt8] = Array(repeating: 0xAA, count: 100)
        let videoPayload: [UInt8] = Array(repeating: 0xBB, count: 200)
        let dataPayload: [UInt8] = Array(repeating: 0xCC, count: 150)

        let audioMsg = RTMPMessage(
            typeID: RTMPMessage.typeIDAudio, streamID: 1,
            timestamp: 0, payload: audioPayload)
        let videoMsg = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 0, payload: videoPayload)
        let dataMsg = RTMPMessage(
            typeID: RTMPMessage.typeIDDataAMF0, streamID: 1,
            timestamp: 0, payload: dataPayload)

        // Interleave: audio, video, data
        var combined: [UInt8] = []
        combined.append(
            contentsOf: disassembler.disassemble(
                message: audioMsg, chunkStreamID: .audio))
        combined.append(
            contentsOf: disassembler.disassemble(
                message: videoMsg, chunkStreamID: .video))
        combined.append(
            contentsOf: disassembler.disassemble(
                message: dataMsg, chunkStreamID: .command))

        let messages = try assembler.process(bytes: combined)
        #expect(messages.count == 3)

        let audio = messages.first { $0.typeID == RTMPMessage.typeIDAudio }
        let video = messages.first { $0.typeID == RTMPMessage.typeIDVideo }
        let data = messages.first { $0.typeID == RTMPMessage.typeIDDataAMF0 }
        #expect(audio?.payload == audioPayload)
        #expect(video?.payload == videoPayload)
        #expect(data?.payload == dataPayload)
    }

    @Test("Zero-length message")
    func zeroLengthMessage() throws {
        var disassembler = ChunkDisassembler(chunkSize: 128)
        var assembler = ChunkAssembler(chunkSize: 128)

        let msg = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo, streamID: 1,
            timestamp: 0, payload: [])

        let chunks = disassembler.disassemble(
            message: msg, chunkStreamID: .video)
        let messages = try assembler.process(bytes: chunks)
        #expect(messages.count == 1)
        #expect(messages[0].payload.isEmpty)
    }
}
