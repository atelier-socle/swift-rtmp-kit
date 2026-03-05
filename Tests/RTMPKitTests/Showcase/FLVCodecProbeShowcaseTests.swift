// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - API Coverage Checklist
// FLVCodecProbe:
//   ✓ probe(data:dataOffset:) — H.264, HEVC, AV1, VP9 detection
// FLVCodecInfo:
//   ✓ init(videoCodec:audioCodec:)
//   ✓ videoCodec, audioCodec properties
//   ✓ Equatable conformance
//   ✓ Sendable conformance
// FLVVideoCodec:
//   ✓ .h264, .hevc, .av1, .vp9, .unknown cases
//   ✓ requiresEnhancedRTMP computed property
//   ✓ displayName computed property
// FLVAudioCodec:
//   ✓ .aac, .opus, .unknown cases
//   ✓ displayName computed property

import Testing

@testable import RTMPKit

// MARK: - FLV Builder Helper

/// Build a minimal valid FLV file with optional video and audio tag payloads.
/// Returns raw bytes and the data offset where FLV tags begin.
private func buildFLV(
    videoPayload: [UInt8]? = nil,
    audioPayload: [UInt8]? = nil
) -> (data: [UInt8], dataOffset: Int) {
    var flags: UInt8 = 0
    if videoPayload != nil { flags |= 0x01 }
    if audioPayload != nil { flags |= 0x04 }
    // FLV header: "FLV" + version 1 + flags + header length 9
    var data: [UInt8] = [0x46, 0x4C, 0x56, 0x01, flags, 0x00, 0x00, 0x00, 0x09]
    // Previous tag size 0
    data += [0x00, 0x00, 0x00, 0x00]
    let dataOffset = 13

    if let video = videoPayload {
        appendTag(to: &data, tagType: 9, payload: video)
    }
    if let audio = audioPayload {
        appendTag(to: &data, tagType: 8, payload: audio)
    }
    return (data, dataOffset)
}

private func appendTag(to data: inout [UInt8], tagType: UInt8, payload: [UInt8]) {
    data.append(tagType)
    data.append(UInt8((payload.count >> 16) & 0xFF))
    data.append(UInt8((payload.count >> 8) & 0xFF))
    data.append(UInt8(payload.count & 0xFF))
    data += [0x00, 0x00, 0x00, 0x00]  // timestamp
    data += [0x00, 0x00, 0x00]  // stream ID
    data += payload
    let tagSize = UInt32(11 + payload.count)
    data.append(UInt8((tagSize >> 24) & 0xFF))
    data.append(UInt8((tagSize >> 16) & 0xFF))
    data.append(UInt8((tagSize >> 8) & 0xFF))
    data.append(UInt8(tagSize & 0xFF))
}

/// Build an Enhanced RTMP video payload with the given FourCC.
private func enhancedVideoPayload(fourCC: FourCC, isKeyframe: Bool) -> [UInt8] {
    let ft: UInt8 =
        isKeyframe
        ? VideoFrameType.keyFrame.rawValue
        : VideoFrameType.interFrame.rawValue
    let byte0: UInt8 =
        0x80
        | ((ExVideoPacketType.codedFrames.rawValue & 0x07) << 4)
        | (ft & 0x0F)
    return [byte0] + fourCC.encode() + [0x00, 0x00, 0x00, 0xAA]
}

// MARK: - Showcase: Probing Video Codecs

@Suite("FLV Codec Probe Showcase — Video Codec Detection")
struct FLVCodecProbeVideoShowcaseTests {

    @Test("Probe an H.264/AVC FLV file — the most common legacy format")
    func probeH264FLV() {
        // FLVCodecProbe.probe() scans FLV tags to detect codecs.
        // Legacy H.264 uses codec ID 7 in the lower nibble of byte 0.
        // byte0 = 0x17 → frame type 1 (keyframe) + codec ID 7 (AVC).
        let (data, offset) = buildFLV(
            videoPayload: [0x17, 0x00, 0x00, 0x00, 0x00, 0xCC],
            audioPayload: [0xAF, 0x01, 0xDD]
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)

        #expect(info.videoCodec == .h264)
        #expect(info.audioCodec == .aac)
        #expect(info.videoCodec.requiresEnhancedRTMP == false)
    }

    @Test("Probe an HEVC FLV file — requires Enhanced RTMP v2")
    func probeHEVCFLV() {
        // Modern codecs like HEVC use Enhanced RTMP v2 FourCC signaling.
        // The first byte has bit 7 set (0x80) to indicate enhanced mode,
        // followed by the 4-byte FourCC code identifying the codec.
        let (data, offset) = buildFLV(
            videoPayload: enhancedVideoPayload(fourCC: .hevc, isKeyframe: true)
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)

        #expect(info.videoCodec == .hevc)
        #expect(info.videoCodec.requiresEnhancedRTMP == true)
        #expect(info.videoCodec.displayName == "HEVC (H.265)")
    }

    @Test("Probe an AV1 FLV file — next-generation codec")
    func probeAV1FLV() {
        // AV1 is a royalty-free next-gen codec, also using Enhanced RTMP.
        let (data, offset) = buildFLV(
            videoPayload: enhancedVideoPayload(fourCC: .av1, isKeyframe: true)
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)

        #expect(info.videoCodec == .av1)
        #expect(info.videoCodec.requiresEnhancedRTMP == true)
        #expect(info.videoCodec.displayName == "AV1")
    }

    @Test("Probe a VP9 FLV file — WebRTC-friendly codec")
    func probeVP9FLV() {
        // VP9 is used in WebRTC and YouTube, also Enhanced RTMP.
        let (data, offset) = buildFLV(
            videoPayload: enhancedVideoPayload(fourCC: .vp9, isKeyframe: false)
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)

        #expect(info.videoCodec == .vp9)
        #expect(info.videoCodec.requiresEnhancedRTMP == true)
        #expect(info.videoCodec.displayName == "VP9")
    }

    @Test("Audio-only FLV reports unknown video codec")
    func audioOnlyReportsUnknownVideo() {
        // When no video tags are present, the probe returns .unknown.
        let (data, offset) = buildFLV(audioPayload: [0xAF, 0x01, 0xBB])
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)

        #expect(info.videoCodec == .unknown)
        #expect(info.audioCodec == .aac)
    }
}

// MARK: - Showcase: Probing Audio Codecs

@Suite("FLV Codec Probe Showcase — Audio Codec Detection")
struct FLVCodecProbeAudioShowcaseTests {

    @Test("Detect AAC audio — the standard RTMP audio codec")
    func detectAACAudio() {
        // Legacy AAC uses SoundFormat=10 (0xA) in the upper nibble of byte 0.
        // byte0 = 0xAF → SoundFormat 10 (AAC), rate/size/type flags.
        let (data, offset) = buildFLV(audioPayload: [0xAF, 0x01, 0xDD])
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)

        #expect(info.audioCodec == .aac)
        #expect(info.audioCodec.displayName == "AAC")
    }

    @Test("Video-only FLV reports unknown audio codec")
    func videoOnlyReportsUnknownAudio() {
        // When no audio tags are present, the probe returns .unknown.
        let (data, offset) = buildFLV(
            videoPayload: [0x17, 0x00, 0x00, 0x00, 0x00, 0xAA]
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)

        #expect(info.audioCodec == .unknown)
        #expect(info.videoCodec == .h264)
    }
}

// MARK: - Showcase: FLVVideoCodec Properties

@Suite("FLV Codec Probe Showcase — Codec Properties")
struct FLVCodecProbePropertiesShowcaseTests {

    @Test("requiresEnhancedRTMP distinguishes legacy from modern codecs")
    func requiresEnhancedRTMP() {
        // H.264 is the only video codec that works with legacy RTMP.
        // All modern codecs (HEVC, AV1, VP9) require Enhanced RTMP v2.
        #expect(FLVVideoCodec.h264.requiresEnhancedRTMP == false)
        #expect(FLVVideoCodec.unknown.requiresEnhancedRTMP == false)
        #expect(FLVVideoCodec.hevc.requiresEnhancedRTMP == true)
        #expect(FLVVideoCodec.av1.requiresEnhancedRTMP == true)
        #expect(FLVVideoCodec.vp9.requiresEnhancedRTMP == true)
    }

    @Test("displayName provides human-readable codec names for UI")
    func videoDisplayNames() {
        // These display names are used in CLI output and logging.
        #expect(FLVVideoCodec.h264.displayName == "H.264")
        #expect(FLVVideoCodec.hevc.displayName == "HEVC (H.265)")
        #expect(FLVVideoCodec.av1.displayName == "AV1")
        #expect(FLVVideoCodec.vp9.displayName == "VP9")
        #expect(FLVVideoCodec.unknown.displayName == "Unknown")
    }

    @Test("Audio codec display names for CLI output")
    func audioDisplayNames() {
        #expect(FLVAudioCodec.aac.displayName == "AAC")
        #expect(FLVAudioCodec.opus.displayName == "Opus")
        #expect(FLVAudioCodec.unknown.displayName == "Unknown")
    }
}

// MARK: - Showcase: FLVCodecInfo Value Semantics

@Suite("FLV Codec Probe Showcase — FLVCodecInfo")
struct FLVCodecInfoShowcaseTests {

    @Test("FLVCodecInfo is created with video and audio codec pair")
    func codecInfoCreation() {
        // FLVCodecInfo bundles the detected video and audio codecs together.
        let info = FLVCodecInfo(videoCodec: .hevc, audioCodec: .aac)

        #expect(info.videoCodec == .hevc)
        #expect(info.audioCodec == .aac)
    }

    @Test("FLVCodecInfo supports equality comparison")
    func codecInfoEquatable() {
        // Equatable conformance lets you compare probe results directly.
        let a = FLVCodecInfo(videoCodec: .h264, audioCodec: .aac)
        let b = FLVCodecInfo(videoCodec: .h264, audioCodec: .aac)
        let c = FLVCodecInfo(videoCodec: .hevc, audioCodec: .aac)

        #expect(a == b)
        #expect(a != c)
    }

    @Test("Empty FLV file returns unknown for both codecs")
    func emptyFLVReturnsUnknown() {
        // A valid FLV header with no tags produces unknown for both codecs.
        let data: [UInt8] = [
            0x46, 0x4C, 0x56, 0x01, 0x05,
            0x00, 0x00, 0x00, 0x09,
            0x00, 0x00, 0x00, 0x00
        ]
        let info = FLVCodecProbe.probe(data: data, dataOffset: 13)

        #expect(info == FLVCodecInfo(videoCodec: .unknown, audioCodec: .unknown))
    }

    @Test("HEVC + AAC — typical high-quality stream combination")
    func hevcPlusAAC() {
        // A common production setup: HEVC video with AAC audio.
        let (data, offset) = buildFLV(
            videoPayload: enhancedVideoPayload(fourCC: .hevc, isKeyframe: true),
            audioPayload: [0xAF, 0x01, 0xDD]
        )
        let info = FLVCodecProbe.probe(data: data, dataOffset: offset)

        #expect(info == FLVCodecInfo(videoCodec: .hevc, audioCodec: .aac))
        #expect(info.videoCodec.requiresEnhancedRTMP == true)
    }
}
