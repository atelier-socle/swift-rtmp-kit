// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("FLV Showcase")
struct FLVShowcaseTests {

    @Test("Build 5 seconds of AAC + H.264 stream")
    func fiveSecondStream() {
        // 1. Audio config
        let audioConfig: [UInt8] = [0x12, 0x10]  // LC, 44100, stereo
        let audioSeqHeader = FLVAudioTag.aacSequenceHeader(audioConfig)
        #expect(audioSeqHeader[0] == 0xAF)
        #expect(audioSeqHeader[1] == 0x00)

        // 2. Video config
        let videoConfig: [UInt8] = Array(repeating: 0x42, count: 30)  // mock SPS/PPS
        let videoSeqHeader = FLVVideoTag.avcSequenceHeader(videoConfig)
        #expect(videoSeqHeader[0] == 0x17)  // keyframe + AVC
        #expect(videoSeqHeader[1] == 0x00)  // sequence header

        // 3. Build 5 seconds of interleaved A/V
        var audioTimestamps: [UInt32] = []
        var videoTimestamps: [UInt32] = []

        // ~43 AAC frames at 23ms intervals ≈ 1 second
        for i in 0..<(43 * 5) {
            let ts = UInt32(i) * 23
            audioTimestamps.append(ts)
            let audioData: [UInt8] = Array(repeating: 0xAA, count: 200)
            let frame = FLVAudioTag.aacRawFrame(audioData)
            #expect(frame[0] == 0xAF)
            #expect(frame[1] == 0x01)  // raw
        }

        // 150 video frames at 30fps
        for i in 0..<150 {
            let ts = UInt32(i) * 33
            videoTimestamps.append(ts)
            let isKeyframe = (i % 60) == 0
            let videoData: [UInt8] = Array(repeating: 0xBB, count: 1000)
            let frame = FLVVideoTag.avcNALU(videoData, isKeyframe: isKeyframe)
            #expect(frame[0] == (isKeyframe ? 0x17 : 0x27))
        }

        // 4. Verify timestamps are monotonically increasing
        for i in 1..<audioTimestamps.count {
            #expect(audioTimestamps[i] > audioTimestamps[i - 1])
        }
        for i in 1..<videoTimestamps.count {
            #expect(videoTimestamps[i] > videoTimestamps[i - 1])
        }
    }

    @Test("FLV header + tags roundtrip")
    func headerRoundtrip() throws {
        let header = FLVHeader(hasAudio: true, hasVideo: true)
        let bytes = header.encode()
        #expect(bytes.count == 9)
        #expect(bytes[0] == 0x46)  // 'F'
        #expect(bytes[1] == 0x4C)  // 'L'
        #expect(bytes[2] == 0x56)  // 'V'
        #expect(bytes[3] == 0x01)  // version 1

        let decoded = try FLVHeader.decode(from: bytes)
        #expect(decoded.hasAudio == true)
        #expect(decoded.hasVideo == true)
    }

    @Test("Audio-only stream")
    func audioOnlyStream() throws {
        let header = FLVHeader(hasAudio: true, hasVideo: false)
        let bytes = header.encode()
        let decoded = try FLVHeader.decode(from: bytes)
        #expect(decoded.hasAudio == true)
        #expect(decoded.hasVideo == false)
    }

    @Test("Video-only stream")
    func videoOnlyStream() throws {
        let header = FLVHeader(hasAudio: false, hasVideo: true)
        let bytes = header.encode()
        let decoded = try FLVHeader.decode(from: bytes)
        #expect(decoded.hasAudio == false)
        #expect(decoded.hasVideo == true)
    }

    @Test("CTS negative values for B-frames")
    func ctsNegativeValues() {
        let videoData: [UInt8] = [0x01, 0x02, 0x03]
        let tag = FLVVideoTag.avcNALU(videoData, isKeyframe: false, cts: -33)

        // Verify CTS is encoded as signed 24-bit
        // Bytes [2..4] are CTS in big-endian signed 24-bit
        let cts = Int32(tag[2]) << 16 | Int32(tag[3]) << 8 | Int32(tag[4])
        // Sign-extend from 24-bit
        let signExtended = cts >= 0x800000 ? cts - 0x1000000 : cts
        #expect(signExtended == -33)
    }

    @Test("Multiple sequence headers mid-stream")
    func multipleSequenceHeaders() {
        // First config (e.g., 720p)
        let config1: [UInt8] = Array(repeating: 0x42, count: 20)
        let seqHeader1 = FLVVideoTag.avcSequenceHeader(config1)
        #expect(seqHeader1[1] == 0x00)

        // Some frames
        let frame1 = FLVVideoTag.avcNALU([0xBB], isKeyframe: true)
        #expect(frame1[0] == 0x17)

        // New config (e.g., 1080p) — mid-stream config change
        let config2: [UInt8] = Array(repeating: 0x55, count: 25)
        let seqHeader2 = FLVVideoTag.avcSequenceHeader(config2)
        #expect(seqHeader2[1] == 0x00)  // still sequence header type

        // More frames with new config
        let frame2 = FLVVideoTag.avcNALU([0xCC], isKeyframe: true)
        #expect(frame2[0] == 0x17)

        // Both configs are valid AVC sequence headers
        #expect(seqHeader1.count != seqHeader2.count)  // different config sizes
    }

    @Test("End of sequence marker")
    func endOfSequenceMarker() {
        let eos = FLVVideoTag.avcEndOfSequence()
        #expect(eos[0] == 0x17)  // keyframe + AVC
        #expect(eos[1] == 0x02)  // end of sequence
        #expect(eos[2] == 0x00)  // CTS = 0
        #expect(eos[3] == 0x00)
        #expect(eos[4] == 0x00)
    }

    @Test("All video frame types")
    func allVideoFrameTypes() {
        // keyframe (1)
        let kf = FLVVideoTag.avcNALU([0x01], isKeyframe: true)
        #expect(kf[0] & 0xF0 == 0x10)  // frame type 1

        // inter-frame (2)
        let inter = FLVVideoTag.avcNALU([0x01], isKeyframe: false)
        #expect(inter[0] & 0xF0 == 0x20)  // frame type 2

        // Check VideoFrameType enum values
        #expect(VideoFrameType.keyFrame.rawValue == 1)
        #expect(VideoFrameType.interFrame.rawValue == 2)
        #expect(VideoFrameType.disposableInterFrame.rawValue == 3)
        #expect(VideoFrameType.commandFrame.rawValue == 5)
    }
}
