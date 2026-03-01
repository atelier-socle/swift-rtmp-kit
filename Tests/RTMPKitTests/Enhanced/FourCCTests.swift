// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("FourCC")
struct FourCCTests {

    // MARK: - String Conversion

    @Test("Create from string hvc1")
    func createFromString() {
        let fcc = FourCC(stringValue: "hvc1")
        #expect(fcc.stringValue == "hvc1")
    }

    @Test("stringValue roundtrip")
    func stringValueRoundtrip() {
        for str in ["hvc1", "av01", "vp09", "Opus", "fLaC", "ac-3", "ec-3", "mp4a"] {
            let fcc = FourCC(stringValue: str)
            #expect(fcc.stringValue == str)
        }
    }

    // MARK: - Well-Known Values

    @Test("All video FourCCs have correct string values")
    func videoFourCCs() {
        #expect(FourCC.hevc.stringValue == "hvc1")
        #expect(FourCC.av1.stringValue == "av01")
        #expect(FourCC.vp9.stringValue == "vp09")
    }

    @Test("All audio FourCCs have correct string values")
    func audioFourCCs() {
        #expect(FourCC.opus.stringValue == "Opus")
        #expect(FourCC.flac.stringValue == "fLaC")
        #expect(FourCC.ac3.stringValue == "ac-3")
        #expect(FourCC.eac3.stringValue == "ec-3")
        #expect(FourCC.mp4a.stringValue == "mp4a")
    }

    // MARK: - Encoding/Decoding

    @Test("encode produces 4 bytes in correct order")
    func encode() {
        let bytes = FourCC.hevc.encode()
        #expect(bytes.count == 4)
        #expect(bytes == [0x68, 0x76, 0x63, 0x31])  // "hvc1" ASCII
    }

    @Test("decode roundtrip from bytes")
    func decodeRoundtrip() throws {
        let original = FourCC.opus
        let bytes = original.encode()
        let decoded = try FourCC.decode(from: bytes)
        #expect(decoded == original)
    }

    @Test("decode truncated data throws")
    func decodeTruncated() {
        #expect(throws: FLVError.self) {
            try FourCC.decode(from: [0x01, 0x02])
        }
    }

    // MARK: - Classification

    @Test("isVideoCodec correct for all values")
    func isVideoCodec() {
        #expect(FourCC.hevc.isVideoCodec)
        #expect(FourCC.av1.isVideoCodec)
        #expect(FourCC.vp9.isVideoCodec)
        #expect(!FourCC.opus.isVideoCodec)
        #expect(!FourCC.flac.isVideoCodec)
    }

    @Test("isAudioCodec correct for all values")
    func isAudioCodec() {
        #expect(FourCC.opus.isAudioCodec)
        #expect(FourCC.flac.isAudioCodec)
        #expect(FourCC.ac3.isAudioCodec)
        #expect(FourCC.eac3.isAudioCodec)
        #expect(FourCC.mp4a.isAudioCodec)
        #expect(!FourCC.hevc.isAudioCodec)
        #expect(!FourCC.av1.isAudioCodec)
    }

    // MARK: - Equatable & Hashable

    @Test("Same FourCC values are equal")
    func equatable() {
        #expect(FourCC.hevc == FourCC(stringValue: "hvc1"))
    }

    @Test("Same FourCC values have same hash")
    func hashable() {
        let a = FourCC.hevc
        let b = FourCC(stringValue: "hvc1")
        #expect(a.hashValue == b.hashValue)
    }

    // MARK: - CustomStringConvertible

    @Test("Description contains string value")
    func description() {
        #expect(FourCC.hevc.description.contains("hvc1"))
    }

    // MARK: - Collection

    @Test("allVideo contains expected values")
    func allVideo() {
        let all = FourCC.allVideo
        #expect(all.contains(.hevc))
        #expect(all.contains(.av1))
        #expect(all.contains(.vp9))
        #expect(all.count == 3)
    }

    @Test("allAudio contains expected values")
    func allAudio() {
        let all = FourCC.allAudio
        #expect(all.contains(.opus))
        #expect(all.contains(.flac))
        #expect(all.contains(.ac3))
        #expect(all.contains(.eac3))
        #expect(all.contains(.mp4a))
        #expect(all.count == 5)
    }
}
