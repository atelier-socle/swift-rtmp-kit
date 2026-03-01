// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ExAudioHeader")
struct ExAudioHeaderTests {

    // MARK: - ExAudioPacketType

    @Test("ExAudioPacketType raw values")
    func packetTypeRawValues() {
        #expect(ExAudioPacketType.sequenceStart.rawValue == 0)
        #expect(ExAudioPacketType.codedFrames.rawValue == 1)
        #expect(ExAudioPacketType.sequenceEnd.rawValue == 2)
        #expect(ExAudioPacketType.multichannelConfig.rawValue == 4)
        #expect(ExAudioPacketType.multitrack.rawValue == 5)
    }

    // MARK: - Encode

    @Test("encode produces 5 bytes")
    func encodeLength() {
        let header = ExAudioHeader(
            packetType: .sequenceStart,
            fourCC: .opus
        )
        #expect(header.encode().count == 5)
    }

    @Test("encode sets isExHeader bit")
    func encodeIsExHeaderBit() {
        let header = ExAudioHeader(packetType: .sequenceStart, fourCC: .opus)
        let bytes = header.encode()
        #expect((bytes[0] & 0x80) != 0)
    }

    @Test("encode packs packetType and channelOrder correctly")
    func encodeBitLayout() {
        // sequenceStart=0, channelOrder=0 → byte0 = 0x80 | (0 << 3) | (0 << 2) = 0x80
        let header = ExAudioHeader(
            packetType: .sequenceStart,
            channelOrder: 0,
            fourCC: .opus
        )
        let bytes = header.encode()
        #expect(bytes[0] == 0x80)
    }

    @Test("encode codedFrames with channelOrder=1")
    func encodeCodedFramesChannelOrder1() {
        // codedFrames=1, channelOrder=1 → byte0 = 0x80 | (1 << 3) | (1 << 2) = 0x8C
        let header = ExAudioHeader(
            packetType: .codedFrames,
            channelOrder: 1,
            fourCC: .flac
        )
        let bytes = header.encode()
        #expect(bytes[0] == 0x8C)
    }

    @Test("encode includes FourCC bytes")
    func encodeFourCC() {
        let header = ExAudioHeader(packetType: .sequenceStart, fourCC: .opus)
        let bytes = header.encode()
        // "Opus" = [0x4F, 0x70, 0x75, 0x73]
        #expect(Array(bytes[1..<5]) == [0x4F, 0x70, 0x75, 0x73])
    }

    // MARK: - Decode

    @Test("decode roundtrip")
    func decodeRoundtrip() throws {
        let original = ExAudioHeader(
            packetType: .codedFrames,
            channelOrder: 1,
            fourCC: .flac
        )
        let bytes = original.encode()
        let decoded = try ExAudioHeader.decode(from: bytes)
        #expect(decoded == original)
    }

    @Test("decode truncated data throws")
    func decodeTruncated() {
        #expect(throws: FLVError.self) {
            try ExAudioHeader.decode(from: [0x80, 0x4F])
        }
    }

    @Test("decode invalid packet type throws")
    func decodeInvalidPacketType() {
        // packetType=3 is invalid → byte0 = 0x80 | (3 << 3) = 0x98
        let bytes: [UInt8] = [0x98, 0x4F, 0x70, 0x75, 0x73]
        #expect(throws: FLVError.self) {
            try ExAudioHeader.decode(from: bytes)
        }
    }

    @Test("decode preserves channelOrder")
    func decodeChannelOrder() throws {
        let header = ExAudioHeader(
            packetType: .sequenceStart,
            channelOrder: 1,
            fourCC: .opus
        )
        let decoded = try ExAudioHeader.decode(from: header.encode())
        #expect(decoded.channelOrder == 1)
    }

    // MARK: - isExHeader

    @Test("isExHeader true when bit 7 set")
    func isExHeaderTrue() {
        #expect(ExAudioHeader.isExHeader(0x80))
        #expect(ExAudioHeader.isExHeader(0xFF))
        #expect(ExAudioHeader.isExHeader(0x8C))
    }

    @Test("isExHeader false when bit 7 clear")
    func isExHeaderFalse() {
        #expect(!ExAudioHeader.isExHeader(0x00))
        #expect(!ExAudioHeader.isExHeader(0x7F))
        #expect(!ExAudioHeader.isExHeader(0x2F))
    }

    // MARK: - Equatable

    @Test("Equatable compares all fields")
    func equatable() {
        let a = ExAudioHeader(packetType: .sequenceStart, channelOrder: 0, fourCC: .opus)
        let b = ExAudioHeader(packetType: .sequenceStart, channelOrder: 0, fourCC: .opus)
        let c = ExAudioHeader(packetType: .sequenceStart, channelOrder: 1, fourCC: .opus)
        #expect(a == b)
        #expect(a != c)
    }
}
