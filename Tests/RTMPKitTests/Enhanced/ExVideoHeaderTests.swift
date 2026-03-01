// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ExVideoHeader")
struct ExVideoHeaderTests {

    // MARK: - ExVideoPacketType

    @Test("ExVideoPacketType raw values")
    func packetTypeRawValues() {
        #expect(ExVideoPacketType.sequenceStart.rawValue == 0)
        #expect(ExVideoPacketType.codedFrames.rawValue == 1)
        #expect(ExVideoPacketType.sequenceEnd.rawValue == 2)
        #expect(ExVideoPacketType.codedFramesX.rawValue == 3)
        #expect(ExVideoPacketType.metadata.rawValue == 4)
        #expect(ExVideoPacketType.mpeg2TSSequenceStart.rawValue == 5)
    }

    // MARK: - VideoFrameType

    @Test("VideoFrameType raw values")
    func frameTypeRawValues() {
        #expect(VideoFrameType.keyFrame.rawValue == 1)
        #expect(VideoFrameType.interFrame.rawValue == 2)
        #expect(VideoFrameType.disposableInterFrame.rawValue == 3)
        #expect(VideoFrameType.commandFrame.rawValue == 5)
    }

    // MARK: - Encode

    @Test("encode produces 5 bytes")
    func encodeLength() {
        let header = ExVideoHeader(
            packetType: .sequenceStart,
            frameType: .keyFrame,
            fourCC: .hevc
        )
        #expect(header.encode().count == 5)
    }

    @Test("encode sets isExHeader bit")
    func encodeIsExHeaderBit() {
        let header = ExVideoHeader(
            packetType: .sequenceStart,
            frameType: .keyFrame,
            fourCC: .hevc
        )
        let bytes = header.encode()
        #expect((bytes[0] & 0x80) != 0)
    }

    @Test("encode packs packetType and frameType correctly")
    func encodeBitLayout() {
        // sequenceStart=0, keyFrame=1 → byte0 = 0x80 | (0 << 4) | 1 = 0x81
        let header = ExVideoHeader(
            packetType: .sequenceStart,
            frameType: .keyFrame,
            fourCC: .hevc
        )
        let bytes = header.encode()
        #expect(bytes[0] == 0x81)
    }

    @Test("encode codedFrames interFrame bit layout")
    func encodeCodedFramesInterFrame() {
        // codedFrames=1, interFrame=2 → byte0 = 0x80 | (1 << 4) | 2 = 0x92
        let header = ExVideoHeader(
            packetType: .codedFrames,
            frameType: .interFrame,
            fourCC: .av1
        )
        let bytes = header.encode()
        #expect(bytes[0] == 0x92)
    }

    @Test("encode includes FourCC bytes")
    func encodeFourCC() {
        let header = ExVideoHeader(
            packetType: .sequenceStart,
            frameType: .keyFrame,
            fourCC: .hevc
        )
        let bytes = header.encode()
        // "hvc1" = [0x68, 0x76, 0x63, 0x31]
        #expect(Array(bytes[1..<5]) == [0x68, 0x76, 0x63, 0x31])
    }

    // MARK: - Decode

    @Test("decode roundtrip")
    func decodeRoundtrip() throws {
        let original = ExVideoHeader(
            packetType: .codedFramesX,
            frameType: .interFrame,
            fourCC: .vp9
        )
        let bytes = original.encode()
        let decoded = try ExVideoHeader.decode(from: bytes)
        #expect(decoded == original)
    }

    @Test("decode truncated data throws")
    func decodeTruncated() {
        #expect(throws: FLVError.self) {
            try ExVideoHeader.decode(from: [0x81, 0x68, 0x76])
        }
    }

    @Test("decode invalid packet type throws")
    func decodeInvalidPacketType() {
        // packetType=7 is invalid → byte0 = 0x80 | (7 << 4) | 1 = 0xF1
        let bytes: [UInt8] = [0xF1, 0x68, 0x76, 0x63, 0x31]
        #expect(throws: FLVError.self) {
            try ExVideoHeader.decode(from: bytes)
        }
    }

    @Test("decode invalid frame type throws")
    func decodeInvalidFrameType() {
        // frameType=0 is invalid → byte0 = 0x80 | (0 << 4) | 0 = 0x80
        let bytes: [UInt8] = [0x80, 0x68, 0x76, 0x63, 0x31]
        #expect(throws: FLVError.self) {
            try ExVideoHeader.decode(from: bytes)
        }
    }

    @Test("decode all packet type + frame type combinations")
    func decodeAllCombinations() throws {
        let packetTypes: [ExVideoPacketType] = [
            .sequenceStart, .codedFrames, .sequenceEnd,
            .codedFramesX, .metadata, .mpeg2TSSequenceStart
        ]
        let frameTypes: [VideoFrameType] = [
            .keyFrame, .interFrame, .disposableInterFrame, .commandFrame
        ]
        for pt in packetTypes {
            for ft in frameTypes {
                let header = ExVideoHeader(packetType: pt, frameType: ft, fourCC: .hevc)
                let decoded = try ExVideoHeader.decode(from: header.encode())
                #expect(decoded == header)
            }
        }
    }

    // MARK: - isExHeader

    @Test("isExHeader true when bit 7 set")
    func isExHeaderTrue() {
        #expect(ExVideoHeader.isExHeader(0x80))
        #expect(ExVideoHeader.isExHeader(0xFF))
        #expect(ExVideoHeader.isExHeader(0x91))
    }

    @Test("isExHeader false when bit 7 clear")
    func isExHeaderFalse() {
        #expect(!ExVideoHeader.isExHeader(0x00))
        #expect(!ExVideoHeader.isExHeader(0x17))
        #expect(!ExVideoHeader.isExHeader(0x7F))
    }

    // MARK: - Equatable

    @Test("Equatable compares all fields")
    func equatable() {
        let a = ExVideoHeader(packetType: .sequenceStart, frameType: .keyFrame, fourCC: .hevc)
        let b = ExVideoHeader(packetType: .sequenceStart, frameType: .keyFrame, fourCC: .hevc)
        let c = ExVideoHeader(packetType: .codedFrames, frameType: .keyFrame, fourCC: .hevc)
        #expect(a == b)
        #expect(a != c)
    }
}
