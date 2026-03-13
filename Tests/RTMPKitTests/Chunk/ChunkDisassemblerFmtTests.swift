// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkDisassembler — Format Selection")
struct ChunkDisassemblerFmtTests {

    @Test("first message uses fmt0 (full header)")
    func firstMessageFmt0() {
        var dis = ChunkDisassembler(chunkSize: 4096)
        let msg = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 100, payload: [0x01, 0x02]
        )
        let bytes = dis.disassemble(message: msg, chunkStreamID: .video)
        // fmt0 basic header: fmt=0 in top 2 bits
        let fmt = (bytes[0] >> 6) & 0x03
        #expect(fmt == 0)
    }

    @Test("same type and length uses fmt2 (timestamp-only)")
    func sameTypeLengthFmt2() {
        var dis = ChunkDisassembler(chunkSize: 4096)
        let msg1 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 100, payload: [0x01, 0x02]
        )
        _ = dis.disassemble(message: msg1, chunkStreamID: .video)

        let msg2 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 133, payload: [0x03, 0x04]
        )
        let bytes = dis.disassemble(message: msg2, chunkStreamID: .video)
        let fmt = (bytes[0] >> 6) & 0x03
        #expect(fmt == 2)  // timestampOnly
    }

    @Test("different message length uses fmt1 (same-stream)")
    func differentLengthFmt1() {
        var dis = ChunkDisassembler(chunkSize: 4096)
        let msg1 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 100, payload: [0x01, 0x02]
        )
        _ = dis.disassemble(message: msg1, chunkStreamID: .video)

        let msg2 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 133, payload: [0x03, 0x04, 0x05]
        )
        let bytes = dis.disassemble(message: msg2, chunkStreamID: .video)
        let fmt = (bytes[0] >> 6) & 0x03
        #expect(fmt == 1)  // sameStream — length differs
    }

    @Test("different message type uses fmt1 (same-stream)")
    func differentTypeFmt1() {
        var dis = ChunkDisassembler(chunkSize: 4096)
        let msg1 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 100, payload: [0x01, 0x02]
        )
        _ = dis.disassemble(message: msg1, chunkStreamID: .video)

        let msg2 = RTMPMessage(
            typeID: RTMPMessage.typeIDAudio,
            streamID: 1, timestamp: 133, payload: [0x03, 0x04]
        )
        let bytes = dis.disassemble(message: msg2, chunkStreamID: .video)
        let fmt = (bytes[0] >> 6) & 0x03
        #expect(fmt == 1)  // sameStream — type differs
    }

    @Test("different stream ID falls back to fmt0")
    func differentStreamIDFmt0() {
        var dis = ChunkDisassembler(chunkSize: 4096)
        let msg1 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 100, payload: [0x01]
        )
        _ = dis.disassemble(message: msg1, chunkStreamID: .video)

        let msg2 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 2, timestamp: 133, payload: [0x01]
        )
        let bytes = dis.disassemble(message: msg2, chunkStreamID: .video)
        let fmt = (bytes[0] >> 6) & 0x03
        #expect(fmt == 0)  // full — stream ID changed
    }

    @Test("fmt2 encodes timestamp delta not absolute")
    func fmt2EncodesDelta() {
        var dis = ChunkDisassembler(chunkSize: 4096)
        let msg1 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 1000, payload: [0x01]
        )
        _ = dis.disassemble(message: msg1, chunkStreamID: .video)

        let msg2 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 1033, payload: [0x02]
        )
        let bytes = dis.disassemble(message: msg2, chunkStreamID: .video)
        // fmt2: basic header (1 byte) + 3-byte timestamp delta
        let fmt = (bytes[0] >> 6) & 0x03
        #expect(fmt == 2)
        // Delta = 1033 - 1000 = 33 = 0x000021
        let delta =
            UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8
            | UInt32(bytes[3])
        #expect(delta == 33)
    }

    @Test("fmt1 encodes timestamp delta and new length")
    func fmt1EncodesDeltaAndLength() {
        var dis = ChunkDisassembler(chunkSize: 4096)
        let msg1 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 500, payload: [0x01]
        )
        _ = dis.disassemble(message: msg1, chunkStreamID: .video)

        let msg2 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 533,
            payload: [0x02, 0x03, 0x04]
        )
        let bytes = dis.disassemble(message: msg2, chunkStreamID: .video)
        let fmt = (bytes[0] >> 6) & 0x03
        #expect(fmt == 1)
        // fmt1: basic header (1) + timestamp delta (3) + message length (3) + type ID (1)
        let delta =
            UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8
            | UInt32(bytes[3])
        #expect(delta == 33)
        let msgLen =
            UInt32(bytes[4]) << 16
            | UInt32(bytes[5]) << 8
            | UInt32(bytes[6])
        #expect(msgLen == 3)
        #expect(bytes[7] == RTMPMessage.typeIDVideo)
    }

    @Test("reset forces fmt0 on next message")
    func resetForcesFmt0() {
        var dis = ChunkDisassembler(chunkSize: 4096)
        let msg = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 100, payload: [0x01]
        )
        _ = dis.disassemble(message: msg, chunkStreamID: .video)
        dis.reset()

        let msg2 = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: 200, payload: [0x01]
        )
        let bytes = dis.disassemble(message: msg2, chunkStreamID: .video)
        let fmt = (bytes[0] >> 6) & 0x03
        #expect(fmt == 0)
    }
}
