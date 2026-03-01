// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("FLVHeader")
struct FLVHeaderTests {

    // MARK: - Defaults

    @Test("Default header has no audio and no video")
    func defaultValues() {
        let header = FLVHeader()
        #expect(!header.hasAudio)
        #expect(!header.hasVideo)
    }

    // MARK: - Encode

    @Test("encode produces 9 bytes")
    func encodeLength() {
        let header = FLVHeader()
        #expect(header.encode().count == 9)
    }

    @Test("encode starts with FLV signature")
    func encodeSignature() {
        let header = FLVHeader()
        let bytes = header.encode()
        #expect(bytes[0] == 0x46)  // 'F'
        #expect(bytes[1] == 0x4C)  // 'L'
        #expect(bytes[2] == 0x56)  // 'V'
    }

    @Test("encode version is 1")
    func encodeVersion() {
        let header = FLVHeader()
        #expect(header.encode()[3] == 0x01)
    }

    @Test("encode data offset is 9")
    func encodeDataOffset() {
        let header = FLVHeader()
        let bytes = header.encode()
        #expect(bytes[5] == 0x00)
        #expect(bytes[6] == 0x00)
        #expect(bytes[7] == 0x00)
        #expect(bytes[8] == 0x09)
    }

    @Test("encode audio-only flag")
    func encodeAudioOnly() {
        let header = FLVHeader(hasAudio: true, hasVideo: false)
        #expect(header.encode()[4] == 0x04)
    }

    @Test("encode video-only flag")
    func encodeVideoOnly() {
        let header = FLVHeader(hasAudio: false, hasVideo: true)
        #expect(header.encode()[4] == 0x01)
    }

    @Test("encode audio+video flags")
    func encodeAudioVideo() {
        let header = FLVHeader(hasAudio: true, hasVideo: true)
        #expect(header.encode()[4] == 0x05)
    }

    @Test("encode no flags")
    func encodeNoFlags() {
        let header = FLVHeader(hasAudio: false, hasVideo: false)
        #expect(header.encode()[4] == 0x00)
    }

    // MARK: - Decode

    @Test("decode roundtrip audio+video")
    func decodeRoundtripAudioVideo() throws {
        let original = FLVHeader(hasAudio: true, hasVideo: true)
        let decoded = try FLVHeader.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("decode roundtrip no flags")
    func decodeRoundtripNoFlags() throws {
        let original = FLVHeader()
        let decoded = try FLVHeader.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("decode truncated data throws")
    func decodeTruncated() {
        #expect(throws: FLVError.self) {
            try FLVHeader.decode(from: [0x46, 0x4C, 0x56])
        }
    }

    @Test("decode invalid signature throws")
    func decodeInvalidSignature() {
        let bytes: [UInt8] = [0x00, 0x00, 0x00, 0x01, 0x05, 0x00, 0x00, 0x00, 0x09]
        #expect(throws: FLVError.self) {
            try FLVHeader.decode(from: bytes)
        }
    }

    // MARK: - Equatable

    @Test("Equatable compares both fields")
    func equatable() {
        let a = FLVHeader(hasAudio: true, hasVideo: false)
        let b = FLVHeader(hasAudio: true, hasVideo: false)
        let c = FLVHeader(hasAudio: true, hasVideo: true)
        #expect(a == b)
        #expect(a != c)
    }
}
