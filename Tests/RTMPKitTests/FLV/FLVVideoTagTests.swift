// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("FLVVideoTag")
struct FLVVideoTagTests {

    // MARK: - Legacy AVC Sequence Header

    @Test("avcSequenceHeader byte 0 is 0x17")
    func avcSequenceHeaderByte0() {
        let body = FLVVideoTag.avcSequenceHeader([0x01])
        #expect(body[0] == 0x17)
    }

    @Test("avcSequenceHeader byte 1 is 0x00 (sequence header)")
    func avcSequenceHeaderByte1() {
        let body = FLVVideoTag.avcSequenceHeader([0x01])
        #expect(body[1] == 0x00)
    }

    @Test("avcSequenceHeader CTS bytes are zero")
    func avcSequenceHeaderCTS() {
        let body = FLVVideoTag.avcSequenceHeader([0x01])
        #expect(body[2] == 0x00)
        #expect(body[3] == 0x00)
        #expect(body[4] == 0x00)
    }

    @Test("avcSequenceHeader includes config")
    func avcSequenceHeaderPayload() {
        let config: [UInt8] = [0x01, 0x64, 0x00, 0x1E]
        let body = FLVVideoTag.avcSequenceHeader(config)
        #expect(body.count == 9)
        #expect(Array(body[5...]) == config)
    }

    // MARK: - Legacy AVC NALU

    @Test("avcNALU keyframe byte 0 is 0x17")
    func avcNALUKeyframeByte0() {
        let body = FLVVideoTag.avcNALU([0xAA], isKeyframe: true)
        #expect(body[0] == 0x17)
    }

    @Test("avcNALU inter frame byte 0 is 0x27")
    func avcNALUInterFrameByte0() {
        let body = FLVVideoTag.avcNALU([0xAA], isKeyframe: false)
        #expect(body[0] == 0x27)
    }

    @Test("avcNALU byte 1 is 0x01 (NALU)")
    func avcNALUByte1() {
        let body = FLVVideoTag.avcNALU([0xAA], isKeyframe: true)
        #expect(body[1] == 0x01)
    }

    @Test("avcNALU default CTS is zero")
    func avcNALUDefaultCTS() {
        let body = FLVVideoTag.avcNALU([0xAA], isKeyframe: true)
        #expect(body[2] == 0x00)
        #expect(body[3] == 0x00)
        #expect(body[4] == 0x00)
    }

    @Test("avcNALU positive CTS encoded correctly")
    func avcNALUPositiveCTS() {
        let body = FLVVideoTag.avcNALU([0xAA], isKeyframe: true, cts: 80)
        // 80 = 0x000050 → [0x00, 0x00, 0x50]
        #expect(body[2] == 0x00)
        #expect(body[3] == 0x00)
        #expect(body[4] == 0x50)
    }

    @Test("avcNALU negative CTS encoded as signed 24-bit")
    func avcNALUNegativeCTS() {
        let body = FLVVideoTag.avcNALU([0xAA], isKeyframe: true, cts: -1)
        // -1 as UInt32 = 0xFFFFFFFF → bottom 24 bits = [0xFF, 0xFF, 0xFF]
        #expect(body[2] == 0xFF)
        #expect(body[3] == 0xFF)
        #expect(body[4] == 0xFF)
    }

    @Test("avcNALU includes data after CTS")
    func avcNALUPayload() {
        let data: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let body = FLVVideoTag.avcNALU(data, isKeyframe: false)
        #expect(body.count == 9)
        #expect(Array(body[5...]) == data)
    }

    // MARK: - Legacy AVC End of Sequence

    @Test("avcEndOfSequence is 5 bytes")
    func avcEndOfSequenceLength() {
        let body = FLVVideoTag.avcEndOfSequence()
        #expect(body.count == 5)
    }

    @Test("avcEndOfSequence byte 0 is 0x17")
    func avcEndOfSequenceByte0() {
        let body = FLVVideoTag.avcEndOfSequence()
        #expect(body[0] == 0x17)
    }

    @Test("avcEndOfSequence byte 1 is 0x02")
    func avcEndOfSequenceByte1() {
        let body = FLVVideoTag.avcEndOfSequence()
        #expect(body[1] == 0x02)
    }

    // MARK: - Enhanced Sequence Start

    @Test("enhancedSequenceStart sets isExHeader bit")
    func enhancedSequenceStartExBit() {
        let body = FLVVideoTag.enhancedSequenceStart(fourCC: .hevc, config: [0x01])
        #expect((body[0] & 0x80) != 0)
    }

    @Test("enhancedSequenceStart packetType is 0")
    func enhancedSequenceStartPacketType() {
        let body = FLVVideoTag.enhancedSequenceStart(fourCC: .hevc, config: [0x01])
        let packetType = (body[0] >> 4) & 0x07
        #expect(packetType == 0)
    }

    @Test("enhancedSequenceStart frameType is keyFrame")
    func enhancedSequenceStartFrameType() {
        let body = FLVVideoTag.enhancedSequenceStart(fourCC: .hevc, config: [0x01])
        let frameType = body[0] & 0x0F
        #expect(frameType == VideoFrameType.keyFrame.rawValue)
    }

    @Test("enhancedSequenceStart includes FourCC")
    func enhancedSequenceStartFourCC() {
        let body = FLVVideoTag.enhancedSequenceStart(fourCC: .hevc, config: [0x01])
        #expect(Array(body[1..<5]) == [0x68, 0x76, 0x63, 0x31])
    }

    @Test("enhancedSequenceStart includes config data")
    func enhancedSequenceStartConfig() {
        let config: [UInt8] = [0x01, 0x02, 0x03]
        let body = FLVVideoTag.enhancedSequenceStart(fourCC: .hevc, config: config)
        #expect(body.count == 8)
        #expect(Array(body[5...]) == config)
    }

    // MARK: - Enhanced Coded Frames (with CTS)

    @Test("enhancedCodedFrames packetType is 1")
    func enhancedCodedFramesPacketType() {
        let body = FLVVideoTag.enhancedCodedFrames(
            fourCC: .hevc, data: [0x01], isKeyframe: true
        )
        let packetType = (body[0] >> 4) & 0x07
        #expect(packetType == 1)
    }

    @Test("enhancedCodedFrames keyframe sets frameType 1")
    func enhancedCodedFramesKeyframe() {
        let body = FLVVideoTag.enhancedCodedFrames(
            fourCC: .hevc, data: [0x01], isKeyframe: true
        )
        let frameType = body[0] & 0x0F
        #expect(frameType == 1)
    }

    @Test("enhancedCodedFrames inter frame sets frameType 2")
    func enhancedCodedFramesInterFrame() {
        let body = FLVVideoTag.enhancedCodedFrames(
            fourCC: .hevc, data: [0x01], isKeyframe: false
        )
        let frameType = body[0] & 0x0F
        #expect(frameType == 2)
    }

    @Test("enhancedCodedFrames includes CTS after FourCC")
    func enhancedCodedFramesCTS() {
        let body = FLVVideoTag.enhancedCodedFrames(
            fourCC: .hevc, data: [0xAA], isKeyframe: true, cts: 100
        )
        // CTS = 100 = 0x000064 → [0x00, 0x00, 0x64]
        #expect(body[5] == 0x00)
        #expect(body[6] == 0x00)
        #expect(body[7] == 0x64)
    }

    @Test("enhancedCodedFrames total length: 1+4+3+data")
    func enhancedCodedFramesLength() {
        let data: [UInt8] = [0xCA, 0xFE]
        let body = FLVVideoTag.enhancedCodedFrames(
            fourCC: .hevc, data: data, isKeyframe: true
        )
        // 1 header + 4 FourCC + 3 CTS + 2 data = 10
        #expect(body.count == 10)
    }

    // MARK: - Enhanced Coded Frames X (no CTS)

    @Test("enhancedCodedFramesX packetType is 3")
    func enhancedCodedFramesXPacketType() {
        let body = FLVVideoTag.enhancedCodedFramesX(
            fourCC: .av1, data: [0x01], isKeyframe: true
        )
        let packetType = (body[0] >> 4) & 0x07
        #expect(packetType == 3)
    }

    @Test("enhancedCodedFramesX has no CTS field")
    func enhancedCodedFramesXNoCTS() {
        let data: [UInt8] = [0xCA, 0xFE]
        let body = FLVVideoTag.enhancedCodedFramesX(
            fourCC: .av1, data: data, isKeyframe: true
        )
        // 1 header + 4 FourCC + 2 data = 7 (no CTS)
        #expect(body.count == 7)
        #expect(Array(body[5...]) == data)
    }

    // MARK: - Enhanced Sequence End

    @Test("enhancedSequenceEnd packetType is 2")
    func enhancedSequenceEndPacketType() {
        let body = FLVVideoTag.enhancedSequenceEnd(fourCC: .hevc)
        let packetType = (body[0] >> 4) & 0x07
        #expect(packetType == 2)
    }

    @Test("enhancedSequenceEnd is 5 bytes")
    func enhancedSequenceEndLength() {
        let body = FLVVideoTag.enhancedSequenceEnd(fourCC: .hevc)
        #expect(body.count == 5)
    }

    // MARK: - Integration

    @Test("Enhanced video uses FourCC from Enhanced module")
    func enhancedUseFourCC() {
        let body = FLVVideoTag.enhancedSequenceStart(fourCC: .hevc, config: [])
        let fccBytes = Array(body[1..<5])
        let decoded = try? FourCC.decode(from: fccBytes)
        #expect(decoded == .hevc)
    }

    @Test("Legacy AVC is not an ex-header")
    func legacyAVCNotExHeader() {
        let body = FLVVideoTag.avcSequenceHeader([0x01])
        #expect(!ExVideoHeader.isExHeader(body[0]))
    }

    @Test("Enhanced video IS an ex-header")
    func enhancedIsExHeader() {
        let body = FLVVideoTag.enhancedSequenceStart(fourCC: .hevc, config: [])
        #expect(ExVideoHeader.isExHeader(body[0]))
    }

}
