// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import RTMPKit
import Testing

@testable import RTMPKitCommands

@Suite("PublishCommand — Keyframe Detection")
struct PublishCommandKeyframeTests {

    @Test("legacy H.264 keyframe detected")
    func legacyKeyframe() {
        // byte0 = 0x17: frameType=1 (keyframe), codecID=7 (AVC)
        let data: [UInt8] = [0x17, 0x01, 0x00, 0x00, 0x00, 0xAA]
        #expect(PublishCommand.isKeyframe(data) == true)
    }

    @Test("legacy H.264 inter frame not keyframe")
    func legacyInterFrame() {
        // byte0 = 0x27: frameType=2 (inter), codecID=7 (AVC)
        let data: [UInt8] = [0x27, 0x01, 0x00, 0x00, 0x00, 0xBB]
        #expect(PublishCommand.isKeyframe(data) == false)
    }

    @Test("enhanced HEVC keyframe detected")
    func enhancedKeyframe() {
        // byte0 = 0x91: isExHeader=1, frameType=1 (keyframe), packetType=1
        let byte0: UInt8 =
            0x80
            | (VideoFrameType.keyFrame.rawValue << 4)
            | ExVideoPacketType.codedFrames.rawValue
        let data: [UInt8] = [byte0] + FourCC.hevc.encode() + [0x00, 0x00, 0x00, 0xCC]
        #expect(PublishCommand.isKeyframe(data) == true)
    }

    @Test("enhanced inter frame not keyframe")
    func enhancedInterFrame() {
        let byte0: UInt8 =
            0x80
            | (VideoFrameType.interFrame.rawValue << 4)
            | ExVideoPacketType.codedFrames.rawValue
        let data: [UInt8] = [byte0] + FourCC.hevc.encode() + [0x00, 0x00, 0x00, 0xDD]
        #expect(PublishCommand.isKeyframe(data) == false)
    }

    @Test("empty data not keyframe")
    func emptyData() {
        #expect(PublishCommand.isKeyframe([]) == false)
    }
}

@Suite("PublishCommand — Video Config Detection")
struct PublishCommandVideoConfigTests {

    @Test("legacy AVC sequence header is config")
    func legacyAVCConfig() {
        // byte0=0x17, byte1=0x00 (AVCPacketType=sequence header)
        let data: [UInt8] = [0x17, 0x00, 0x00, 0x00, 0x00, 0xAA]
        #expect(PublishCommand.isVideoConfig(data) == true)
    }

    @Test("legacy AVC NALU is not config")
    func legacyAVCNALU() {
        // byte0=0x17, byte1=0x01 (AVCPacketType=NALU)
        let data: [UInt8] = [0x17, 0x01, 0x00, 0x00, 0x00, 0xBB]
        #expect(PublishCommand.isVideoConfig(data) == false)
    }

    @Test("enhanced sequence start is config")
    func enhancedSequenceStart() {
        let byte0: UInt8 =
            0x80
            | (VideoFrameType.keyFrame.rawValue << 4)
            | ExVideoPacketType.sequenceStart.rawValue
        let data: [UInt8] = [byte0] + FourCC.hevc.encode() + [0xDE, 0xAD]
        #expect(PublishCommand.isVideoConfig(data) == true)
    }

    @Test("enhanced coded frames is not config")
    func enhancedCodedFrames() {
        let byte0: UInt8 =
            0x80
            | (VideoFrameType.keyFrame.rawValue << 4)
            | ExVideoPacketType.codedFrames.rawValue
        let data: [UInt8] = [byte0] + FourCC.hevc.encode() + [0x00, 0x00, 0x00, 0xCC]
        #expect(PublishCommand.isVideoConfig(data) == false)
    }

    @Test("empty data is not config")
    func emptyData() {
        #expect(PublishCommand.isVideoConfig([]) == false)
    }
}

@Suite("PublishCommand — Audio Config Detection")
struct PublishCommandAudioConfigTests {

    @Test("legacy AAC sequence header is config")
    func legacyAACConfig() {
        // byte0=0xAF, byte1=0x00 (AACPacketType=sequence header)
        let data: [UInt8] = [0xAF, 0x00, 0xAA, 0xBB]
        #expect(PublishCommand.isAudioConfig(data) == true)
    }

    @Test("legacy AAC raw frame is not config")
    func legacyAACRaw() {
        // byte0=0xAF, byte1=0x01 (AACPacketType=raw)
        let data: [UInt8] = [0xAF, 0x01, 0xCC]
        #expect(PublishCommand.isAudioConfig(data) == false)
    }

    @Test("enhanced audio sequence start is config")
    func enhancedAudioConfig() {
        let byte0: UInt8 = 0x80 | (ExAudioPacketType.sequenceStart.rawValue << 3)
        let data: [UInt8] = [byte0] + FourCC.opus.encode() + [0xDD]
        #expect(PublishCommand.isAudioConfig(data) == true)
    }

    @Test("enhanced audio coded frames is not config")
    func enhancedAudioCoded() {
        let byte0: UInt8 = 0x80 | (ExAudioPacketType.codedFrames.rawValue << 3)
        let data: [UInt8] = [byte0] + FourCC.opus.encode() + [0xEE]
        #expect(PublishCommand.isAudioConfig(data) == false)
    }

    @Test("empty data is not audio config")
    func emptyData() {
        #expect(PublishCommand.isAudioConfig([]) == false)
    }
}
