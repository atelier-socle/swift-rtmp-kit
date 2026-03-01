// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Enhanced RTMP Showcase")
struct EnhancedRTMPShowcaseTests {

    @Test("HEVC publishing with FourCC negotiation")
    func hevcPublishing() throws {
        // 1. Build connect command with fourCcList
        let codecs: [FourCC] = [.hevc]
        let fourCcAMF = EnhancedRTMP.fourCcListAMF0(codecs: codecs)
        let parsed = EnhancedRTMP.parseFourCcList(from: fourCcAMF)
        #expect(parsed == [.hevc])

        // 2. Build HEVC sequence header
        let config: [UInt8] = Array(repeating: 0x42, count: 30)
        let seqHeader = FLVVideoTag.enhancedSequenceStart(
            fourCC: .hevc, config: config)
        #expect(ExVideoHeader.isExHeader(seqHeader[0]))

        // 3. Build HEVC coded frames (with CTS)
        let frameData: [UInt8] = Array(repeating: 0xBB, count: 500)
        let codedFrame = FLVVideoTag.enhancedCodedFrames(
            fourCC: .hevc, data: frameData, isKeyframe: true, cts: 33)
        #expect(ExVideoHeader.isExHeader(codedFrame[0]))

        // 4. Verify ExVideoHeader bit layout
        let headerByte = seqHeader[0]
        #expect(headerByte & 0x80 != 0)  // isExHeader = 1
    }

    @Test("AV1 publishing without CTS")
    func av1PublishingNoCTS() {
        // 1. Build AV1 sequence start
        let config: [UInt8] = [0x81, 0x04, 0x0C, 0x00]  // mock OBU
        let seqStart = FLVVideoTag.enhancedSequenceStart(
            fourCC: .av1, config: config)
        #expect(ExVideoHeader.isExHeader(seqStart[0]))

        // 2. Build AV1 coded frames X (no CTS)
        let frameData: [UInt8] = Array(repeating: 0xAA, count: 200)
        let codedFrameX = FLVVideoTag.enhancedCodedFramesX(
            fourCC: .av1, data: frameData, isKeyframe: true)
        #expect(ExVideoHeader.isExHeader(codedFrameX[0]))

        // 3. Verify CodedFramesX uses packet type 3
        let header = try? ExVideoHeader.decode(from: Array(codedFrameX.prefix(5)))
        #expect(header?.packetType == .codedFramesX)
    }

    @Test("Opus audio via Enhanced RTMP")
    func opusAudioEnhanced() throws {
        // 1. Build enhanced audio tag with FourCC = Opus
        let config: [UInt8] = [0x01, 0x02]  // mock Opus config
        let seqStart = FLVAudioTag.enhancedSequenceStart(
            fourCC: .opus, config: config)
        #expect(ExAudioHeader.isExHeader(seqStart[0]))

        // 2. Verify ExAudioHeader bit layout
        let headerByte = seqStart[0]
        #expect(headerByte & 0x80 != 0)  // isExHeader = 1

        // 3. Sequence header + data frame
        let audioData: [UInt8] = Array(repeating: 0x77, count: 100)
        let frame = FLVAudioTag.enhancedCodedFrame(
            fourCC: .opus, data: audioData)
        #expect(ExAudioHeader.isExHeader(frame[0]))

        // Decode header
        let decodedHeader = try ExAudioHeader.decode(from: Array(frame.prefix(5)))
        #expect(decodedHeader.fourCC == .opus)
        #expect(decodedHeader.packetType == .codedFrames)
    }

    @Test("Multi-codec fourCcList roundtrip")
    func multiCodecFourCcList() throws {
        let codecs: [FourCC] = [.hevc, .av1, .vp9, .opus, .flac, .ac3, .eac3]
        let amfValue = EnhancedRTMP.fourCcListAMF0(codecs: codecs)

        var encoder = AMF0Encoder()
        let bytes = encoder.encode(amfValue)
        var decoder = AMF0Decoder()
        let decoded = try decoder.decode(from: bytes)

        let parsed = EnhancedRTMP.parseFourCcList(from: decoded)
        #expect(parsed.count == 7)
        #expect(parsed[0] == .hevc)
        #expect(parsed[1] == .av1)
        #expect(parsed[2] == .vp9)
        #expect(parsed[3] == .opus)
        #expect(parsed[4] == .flac)
        #expect(parsed[5] == .ac3)
        #expect(parsed[6] == .eac3)
    }

    @Test("All 8 known FourCC constants")
    func allFourCCConstants() {
        // Video
        #expect(FourCC.hevc.stringValue == "hvc1")
        #expect(FourCC.av1.stringValue == "av01")
        #expect(FourCC.vp9.stringValue == "vp09")

        // Audio
        #expect(FourCC.opus.stringValue == "Opus")
        #expect(FourCC.flac.stringValue == "fLaC")
        #expect(FourCC.ac3.stringValue == "ac-3")
        #expect(FourCC.eac3.stringValue == "ec-3")
        #expect(FourCC.mp4a.stringValue == "mp4a")

        // Video codec detection
        #expect(FourCC.hevc.isVideoCodec)
        #expect(FourCC.av1.isVideoCodec)
        #expect(FourCC.vp9.isVideoCodec)
        #expect(!FourCC.opus.isVideoCodec)

        // Audio codec detection
        #expect(FourCC.opus.isAudioCodec)
        #expect(FourCC.flac.isAudioCodec)
        #expect(!FourCC.hevc.isAudioCodec)

        // Equatable
        #expect(FourCC.hevc == FourCC(stringValue: "hvc1"))
        #expect(FourCC.hevc != FourCC.av1)

        // Encode produces 4 bytes
        #expect(FourCC.hevc.encode().count == 4)
    }

    @Test("Enhanced RTMP fallback when server doesn't support it")
    func fallbackToLegacy() {
        // Server _result without fourCcList
        let serverResponse: AMF0Value = .object([
            ("fmsVer", .string("FMS/5,0")),
            ("capabilities", .number(31))
        ])

        let parsed = EnhancedRTMP.parseFourCcList(from: serverResponse)
        #expect(parsed.isEmpty)

        // Client should use legacy FLV tags
        let enhanced = EnhancedRTMP(
            isEnabled: true, negotiatedCodecs: parsed)
        #expect(enhanced.negotiatedCodecs.isEmpty)
        #expect(!enhanced.supports(.hevc))

        // Legacy tags still work
        let legacyVideo = FLVVideoTag.avcNALU([0x01], isKeyframe: true)
        #expect(!ExVideoHeader.isExHeader(legacyVideo[0]))
    }

    @Test("All 6 ExVideoPacketType values")
    func allExVideoPacketTypes() {
        let types: [(ExVideoPacketType, UInt8)] = [
            (.sequenceStart, 0),
            (.codedFrames, 1),
            (.sequenceEnd, 2),
            (.codedFramesX, 3),
            (.metadata, 4),
            (.mpeg2TSSequenceStart, 5)
        ]
        for (packetType, rawValue) in types {
            #expect(packetType.rawValue == rawValue)

            let header = ExVideoHeader(
                packetType: packetType,
                frameType: .keyFrame,
                fourCC: .hevc)
            let encoded = header.encode()
            #expect(ExVideoHeader.isExHeader(encoded[0]))
        }
    }

    @Test("Multitrack stub types exist")
    func multitrackStubTypes() {
        #expect(MultitrackType.oneTrack.rawValue == 0)
        #expect(MultitrackType.manyTracks.rawValue == 1)
        #expect(MultitrackType.manyTracksManyCodecs.rawValue == 2)
    }
}
