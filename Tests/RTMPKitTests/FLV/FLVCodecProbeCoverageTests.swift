// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("FLVCodecProbe — Unknown Codec Detection")
struct FLVCodecProbeUnknownCodecTests {

    /// Build a minimal FLV file with given tag type and first payload byte.
    private func buildFLV(
        tagType: UInt8, payloadByte: UInt8
    ) -> [UInt8] {
        // FLV header: "FLV" + version 1 + flags 5 (A+V) + data offset 9
        var flv: [UInt8] = [
            0x46, 0x4C, 0x56, 0x01, 0x05,
            0x00, 0x00, 0x00, 0x09,
            // Previous tag size 0
            0x00, 0x00, 0x00, 0x00
        ]

        // Tag header: type(1) + dataSize(3) + timestamp(3) + timestampExt(1) + streamID(3)
        let dataSize: UInt32 = 2  // 2 bytes of payload
        flv.append(tagType)
        flv.append(UInt8((dataSize >> 16) & 0xFF))
        flv.append(UInt8((dataSize >> 8) & 0xFF))
        flv.append(UInt8(dataSize & 0xFF))
        flv.append(contentsOf: [0x00, 0x00, 0x00])  // timestamp
        flv.append(0x00)  // timestamp ext
        flv.append(contentsOf: [0x00, 0x00, 0x00])  // stream ID

        // Tag body
        flv.append(payloadByte)
        flv.append(0x00)

        // Previous tag size
        let tagSize = UInt32(11 + dataSize)
        flv.append(UInt8((tagSize >> 24) & 0xFF))
        flv.append(UInt8((tagSize >> 16) & 0xFF))
        flv.append(UInt8((tagSize >> 8) & 0xFF))
        flv.append(UInt8(tagSize & 0xFF))

        return flv
    }

    @Test("non-AVC legacy video codec returns .unknown")
    func unknownVideoCodec() {
        // Sorenson H.263 = codecID 2, frameType 1 → 0x12
        let flv = buildFLV(tagType: 9, payloadByte: 0x12)
        let info = FLVCodecProbe.probe(data: flv, dataOffset: 13)
        #expect(info.videoCodec == .unknown)
    }

    @Test("non-AAC legacy audio format returns .unknown")
    func unknownAudioCodec() {
        // MP3 = soundFormat 2, upper nibble 0x20
        let flv = buildFLV(tagType: 8, payloadByte: 0x20)
        let info = FLVCodecProbe.probe(data: flv, dataOffset: 13)
        #expect(info.audioCodec == .unknown)
    }
}
