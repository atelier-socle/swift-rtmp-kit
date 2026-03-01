// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("FLVAudioTag")
struct FLVAudioTagTests {

    // MARK: - Legacy AAC

    @Test("aacSequenceHeader byte 0 is 0xAF")
    func aacSequenceHeaderByte0() {
        let body = FLVAudioTag.aacSequenceHeader([0x12, 0x10])
        #expect(body[0] == 0xAF)
    }

    @Test("aacSequenceHeader byte 1 is 0x00")
    func aacSequenceHeaderByte1() {
        let body = FLVAudioTag.aacSequenceHeader([0x12, 0x10])
        #expect(body[1] == 0x00)
    }

    @Test("aacSequenceHeader includes config data")
    func aacSequenceHeaderPayload() {
        let config: [UInt8] = [0x12, 0x10]
        let body = FLVAudioTag.aacSequenceHeader(config)
        #expect(body.count == 4)
        #expect(Array(body[2...]) == config)
    }

    @Test("aacRawFrame byte 0 is 0xAF")
    func aacRawFrameByte0() {
        let body = FLVAudioTag.aacRawFrame([0xDE, 0xAD])
        #expect(body[0] == 0xAF)
    }

    @Test("aacRawFrame byte 1 is 0x01")
    func aacRawFrameByte1() {
        let body = FLVAudioTag.aacRawFrame([0xDE, 0xAD])
        #expect(body[1] == 0x01)
    }

    @Test("aacRawFrame includes frame data")
    func aacRawFramePayload() {
        let data: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let body = FLVAudioTag.aacRawFrame(data)
        #expect(body.count == 6)
        #expect(Array(body[2...]) == data)
    }

    @Test("aacSequenceHeader empty config")
    func aacSequenceHeaderEmptyConfig() {
        let body = FLVAudioTag.aacSequenceHeader([])
        #expect(body == [0xAF, 0x00])
    }

    // MARK: - Enhanced Audio

    @Test("enhancedSequenceStart sets isExHeader bit")
    func enhancedSequenceStartExBit() {
        let body = FLVAudioTag.enhancedSequenceStart(fourCC: .opus, config: [0x01])
        #expect((body[0] & 0x80) != 0)
    }

    @Test("enhancedSequenceStart packetType is 0")
    func enhancedSequenceStartPacketType() {
        let body = FLVAudioTag.enhancedSequenceStart(fourCC: .opus, config: [0x01])
        let packetType = (body[0] >> 3) & 0x0F
        #expect(packetType == 0)
    }

    @Test("enhancedSequenceStart includes FourCC")
    func enhancedSequenceStartFourCC() {
        let body = FLVAudioTag.enhancedSequenceStart(fourCC: .opus, config: [0x01])
        // "Opus" = [0x4F, 0x70, 0x75, 0x73]
        #expect(Array(body[1..<5]) == [0x4F, 0x70, 0x75, 0x73])
    }

    @Test("enhancedSequenceStart includes config after FourCC")
    func enhancedSequenceStartConfig() {
        let config: [UInt8] = [0xAA, 0xBB]
        let body = FLVAudioTag.enhancedSequenceStart(fourCC: .opus, config: config)
        #expect(body.count == 7)
        #expect(Array(body[5...]) == config)
    }

    @Test("enhancedCodedFrame sets packetType 1")
    func enhancedCodedFramePacketType() {
        let body = FLVAudioTag.enhancedCodedFrame(fourCC: .flac, data: [0x01])
        let packetType = (body[0] >> 3) & 0x0F
        #expect(packetType == 1)
    }

    @Test("enhancedCodedFrame includes FourCC and data")
    func enhancedCodedFramePayload() {
        let data: [UInt8] = [0xCA, 0xFE]
        let body = FLVAudioTag.enhancedCodedFrame(fourCC: .flac, data: data)
        // 1 header + 4 FourCC + 2 data = 7
        #expect(body.count == 7)
        #expect(Array(body[5...]) == data)
    }

    @Test("enhancedSequenceEnd sets packetType 2")
    func enhancedSequenceEndPacketType() {
        let body = FLVAudioTag.enhancedSequenceEnd(fourCC: .opus)
        let packetType = (body[0] >> 3) & 0x0F
        #expect(packetType == 2)
    }

    @Test("enhancedSequenceEnd is 5 bytes")
    func enhancedSequenceEndLength() {
        let body = FLVAudioTag.enhancedSequenceEnd(fourCC: .opus)
        #expect(body.count == 5)
    }

    @Test("enhancedSequenceEnd includes FourCC")
    func enhancedSequenceEndFourCC() {
        let body = FLVAudioTag.enhancedSequenceEnd(fourCC: .ac3)
        // "ac-3" = [0x61, 0x63, 0x2D, 0x33]
        #expect(Array(body[1..<5]) == [0x61, 0x63, 0x2D, 0x33])
    }

    // MARK: - Integration

    @Test("Enhanced audio uses FourCC from Enhanced module")
    func enhancedUseFourCC() {
        let body = FLVAudioTag.enhancedSequenceStart(fourCC: .opus, config: [])
        let fccBytes = Array(body[1..<5])
        let decoded = try? FourCC.decode(from: fccBytes)
        #expect(decoded == .opus)
    }

    @Test("Legacy AAC byte 0 is 0xAF")
    func legacyAACByte0Value() {
        let body = FLVAudioTag.aacSequenceHeader([0x12, 0x10])
        #expect(body[0] == 0xAF)
    }

    @Test("Enhanced audio IS an ex-header")
    func enhancedIsExHeader() {
        let body = FLVAudioTag.enhancedSequenceStart(fourCC: .opus, config: [])
        #expect(ExAudioHeader.isExHeader(body[0]))
    }
}
