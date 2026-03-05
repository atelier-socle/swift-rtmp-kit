// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Helpers

/// Build a minimal FLV file with one video and/or one audio tag.
private func buildFLV(
    videoPayload: [UInt8]? = nil,
    audioPayload: [UInt8]? = nil
) -> (data: [UInt8], dataOffset: Int) {
    // FLV header: "FLV", version 1, flags, header length 9
    var flags: UInt8 = 0
    if videoPayload != nil { flags |= 0x01 }
    if audioPayload != nil { flags |= 0x04 }
    var data: [UInt8] = [0x46, 0x4C, 0x56, 0x01, flags, 0x00, 0x00, 0x00, 0x09]
    // Previous tag size 0
    data += [0x00, 0x00, 0x00, 0x00]
    let dataOffset = 13

    if let video = videoPayload {
        // Tag type 9 (video)
        data.append(9)
        // Data size (3 bytes big-endian)
        data.append(UInt8((video.count >> 16) & 0xFF))
        data.append(UInt8((video.count >> 8) & 0xFF))
        data.append(UInt8(video.count & 0xFF))
        // Timestamp (3 bytes) + extended (1 byte)
        data += [0x00, 0x00, 0x00, 0x00]
        // Stream ID (3 bytes)
        data += [0x00, 0x00, 0x00]
        // Payload
        data += video
        // Previous tag size
        let tagSize = UInt32(11 + video.count)
        data.append(UInt8((tagSize >> 24) & 0xFF))
        data.append(UInt8((tagSize >> 16) & 0xFF))
        data.append(UInt8((tagSize >> 8) & 0xFF))
        data.append(UInt8(tagSize & 0xFF))
    }

    if let audio = audioPayload {
        // Tag type 8 (audio)
        data.append(8)
        // Data size (3 bytes big-endian)
        data.append(UInt8((audio.count >> 16) & 0xFF))
        data.append(UInt8((audio.count >> 8) & 0xFF))
        data.append(UInt8(audio.count & 0xFF))
        // Timestamp (3 bytes) + extended (1 byte)
        data += [0x00, 0x00, 0x00, 0x00]
        // Stream ID (3 bytes)
        data += [0x00, 0x00, 0x00]
        // Payload
        data += audio
        // Previous tag size
        let tagSize = UInt32(11 + audio.count)
        data.append(UInt8((tagSize >> 24) & 0xFF))
        data.append(UInt8((tagSize >> 16) & 0xFF))
        data.append(UInt8((tagSize >> 8) & 0xFF))
        data.append(UInt8(tagSize & 0xFF))
    }

    return (data, dataOffset)
}

/// Build enhanced video payload: byte0 + FourCC + dummy data.
private func enhancedVideoPayload(fourCC: FourCC, isKeyframe: Bool) -> [UInt8] {
    let ft: UInt8 = isKeyframe ? VideoFrameType.keyFrame.rawValue : VideoFrameType.interFrame.rawValue
    let byte0: UInt8 = 0x80 | ((ExVideoPacketType.codedFrames.rawValue & 0x07) << 4) | (ft & 0x0F)
    return [byte0] + fourCC.encode() + [0x00, 0x00, 0x00, 0xAA]
}

/// Build enhanced audio payload: byte0 + FourCC + dummy data.
private func enhancedAudioPayload(fourCC: FourCC) -> [UInt8] {
    let byte0: UInt8 = 0x80 | ((ExAudioPacketType.codedFrames.rawValue & 0x0F) << 3)
    return [byte0] + fourCC.encode() + [0xBB]
}

// MARK: - Tests

@Suite("FLVCodecProbe — Video Detection")
struct FLVCodecProbeVideoTests {

    @Test("detects H.264 from legacy AVC keyframe")
    func detectH264() {
        // Legacy AVC keyframe: byte0 = 0x17 (frameType=1, codecID=7)
        let (data, offset) = buildFLV(
            videoPayload: [0x17, 0x00, 0x00, 0x00, 0x00, 0xAA]
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.videoCodec == .h264)
    }

    @Test("detects HEVC from enhanced video tag")
    func detectHEVC() {
        let (data, offset) = buildFLV(
            videoPayload: enhancedVideoPayload(fourCC: .hevc, isKeyframe: true)
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.videoCodec == .hevc)
    }

    @Test("detects AV1 from enhanced video tag")
    func detectAV1() {
        let (data, offset) = buildFLV(
            videoPayload: enhancedVideoPayload(fourCC: .av1, isKeyframe: true)
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.videoCodec == .av1)
    }

    @Test("detects VP9 from enhanced video tag")
    func detectVP9() {
        let (data, offset) = buildFLV(
            videoPayload: enhancedVideoPayload(fourCC: .vp9, isKeyframe: false)
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.videoCodec == .vp9)
    }

    @Test("returns unknown for audio-only FLV")
    func audioOnlyUnknownVideo() {
        let (data, offset) = buildFLV(
            audioPayload: [0xAF, 0x01, 0xDD]
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.videoCodec == .unknown)
    }
}

@Suite("FLVCodecProbe — Audio Detection")
struct FLVCodecProbeAudioTests {

    @Test("detects AAC from legacy audio tag")
    func detectAAC() {
        let (data, offset) = buildFLV(
            audioPayload: [0xAF, 0x01, 0xDD]
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.audioCodec == .aac)
    }

    @Test("detects Opus from enhanced audio tag")
    func detectOpus() {
        let (data, offset) = buildFLV(
            audioPayload: enhancedAudioPayload(fourCC: .opus)
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.audioCodec == .opus)
    }

    @Test("returns unknown for video-only FLV")
    func videoOnlyUnknownAudio() {
        let (data, offset) = buildFLV(
            videoPayload: [0x17, 0x00, 0x00, 0x00, 0x00, 0xAA]
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.audioCodec == .unknown)
    }
}

@Suite("FLVCodecProbe — Combined and Edge Cases")
struct FLVCodecProbeCombinedTests {

    @Test("empty FLV returns unknown for both codecs")
    func emptyFLV() {
        // Just FLV header + prev tag size, no tags
        let data: [UInt8] = [
            0x46, 0x4C, 0x56, 0x01, 0x05,
            0x00, 0x00, 0x00, 0x09,
            0x00, 0x00, 0x00, 0x00
        ]
        let info = FLVCodecProbe.probe(data: data, dataOffset: 13)
        #expect(info.videoCodec == .unknown)
        #expect(info.audioCodec == .unknown)
    }

    @Test("H.264 + AAC detected together")
    func h264PlusAAC() {
        let (data, offset) = buildFLV(
            videoPayload: [0x17, 0x00, 0x00, 0x00, 0x00, 0xAA],
            audioPayload: [0xAF, 0x01, 0xDD]
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.videoCodec == .h264)
        #expect(info.audioCodec == .aac)
    }

    @Test("HEVC + Opus detected together")
    func hevcPlusOpus() {
        let (data, offset) = buildFLV(
            videoPayload: enhancedVideoPayload(fourCC: .hevc, isKeyframe: true),
            audioPayload: enhancedAudioPayload(fourCC: .opus)
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)
        #expect(info.videoCodec == .hevc)
        #expect(info.audioCodec == .opus)
    }

    @Test("FLVCodecInfo is equatable")
    func codecInfoEquatable() {
        let a = FLVCodecInfo(videoCodec: .hevc, audioCodec: .aac)
        let b = FLVCodecInfo(videoCodec: .hevc, audioCodec: .aac)
        let c = FLVCodecInfo(videoCodec: .h264, audioCodec: .aac)
        #expect(a == b)
        #expect(a != c)
    }
}

@Suite("FLVVideoCodec — Properties")
struct FLVVideoCodecPropertiesTests {

    @Test("requiresEnhancedRTMP for each codec")
    func requiresEnhancedRTMP() {
        #expect(FLVVideoCodec.h264.requiresEnhancedRTMP == false)
        #expect(FLVVideoCodec.hevc.requiresEnhancedRTMP == true)
        #expect(FLVVideoCodec.av1.requiresEnhancedRTMP == true)
        #expect(FLVVideoCodec.vp9.requiresEnhancedRTMP == true)
        #expect(FLVVideoCodec.unknown.requiresEnhancedRTMP == false)
    }

    @Test("displayName for each codec")
    func displayNames() {
        #expect(FLVVideoCodec.h264.displayName == "H.264")
        #expect(FLVVideoCodec.hevc.displayName == "HEVC (H.265)")
        #expect(FLVVideoCodec.av1.displayName == "AV1")
        #expect(FLVVideoCodec.vp9.displayName == "VP9")
        #expect(FLVVideoCodec.unknown.displayName == "Unknown")
    }
}

@Suite("FLVAudioCodec — Properties")
struct FLVAudioCodecPropertiesTests {

    @Test("displayName for each audio codec")
    func displayNames() {
        #expect(FLVAudioCodec.aac.displayName == "AAC")
        #expect(FLVAudioCodec.opus.displayName == "Opus")
        #expect(FLVAudioCodec.unknown.displayName == "Unknown")
    }
}
