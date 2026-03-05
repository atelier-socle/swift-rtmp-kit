// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

@Suite("FLVWriter")
struct FLVWriterTests {

    private func tempPath() -> String {
        "/tmp/rtmpkit_flvtest_\(DispatchTime.now().uptimeNanoseconds).flv"
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("init creates a file at the given path")
    func createsFile() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        _ = try FLVWriter(path: path)
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("FLV header bytes are correct: FLV + version")
    func headerBytes() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path)
        _ = try await writer.close()

        let data = FileManager.default.contents(atPath: path)
        #expect(data != nil)
        let bytes = [UInt8](data ?? Data())
        #expect(bytes.count >= 9)
        // "FLV" signature
        #expect(bytes[0] == 0x46)
        #expect(bytes[1] == 0x4C)
        #expect(bytes[2] == 0x56)
        // Version
        #expect(bytes[3] == 0x01)
    }

    @Test("header flags: 0x05 for video+audio")
    func headerFlagsVideoAudio() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path, hasVideo: true, hasAudio: true)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        #expect(bytes[4] == 0x05)
    }

    @Test("header flags: 0x04 for video only")
    func headerFlagsVideoOnly() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path, hasVideo: true, hasAudio: false)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        #expect(bytes[4] == 0x01)  // FLVHeader: hasVideo = bit 0
    }

    @Test("header flags: 0x01 for audio only")
    func headerFlagsAudioOnly() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path, hasVideo: false, hasAudio: true)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        #expect(bytes[4] == 0x04)  // FLVHeader: hasAudio = bit 2
    }

    @Test("first PreviousTagSize after header is 0x00000000")
    func firstPreviousTagSize() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        // Bytes 9-12 should be 0x00000000
        #expect(bytes[9] == 0x00)
        #expect(bytes[10] == 0x00)
        #expect(bytes[11] == 0x00)
        #expect(bytes[12] == 0x00)
    }

    @Test("writeVideo increases videoFrameCount by 1")
    func videoFrameCountIncreases() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path)
        try await writer.writeVideo([0x01, 0x02], timestamp: 0, isKeyframe: true)
        let count = await writer.videoFrameCount
        #expect(count == 1)
        _ = try await writer.close()
    }

    @Test("writeAudio increases audioFrameCount by 1")
    func audioFrameCountIncreases() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path)
        try await writer.writeAudio([0xAA, 0xBB], timestamp: 0)
        let count = await writer.audioFrameCount
        #expect(count == 1)
        _ = try await writer.close()
    }

    @Test("writeVideo produces a tag with type byte 0x09")
    func videoTagType() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path)
        try await writer.writeVideo([0x01], timestamp: 0, isKeyframe: true)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        // After header (9 bytes) + PrevTagSize (4 bytes) = byte 13 is first tag type
        #expect(bytes[13] == 0x09)
    }

    @Test("writeAudio produces a tag with type byte 0x08")
    func audioTagType() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path)
        try await writer.writeAudio([0xAA], timestamp: 0)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        #expect(bytes[13] == 0x08)
    }

    @Test("bytesWritten increases after each write")
    func bytesWrittenIncreases() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path)
        let initial = await writer.bytesWritten
        try await writer.writeVideo([0x01, 0x02, 0x03], timestamp: 0, isKeyframe: true)
        let after = await writer.bytesWritten
        #expect(after > initial)
        _ = try await writer.close()
    }

    @Test("close returns RecordingSegment with correct videoFrameCount")
    func closeReturnsSegment() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path)
        try await writer.writeVideo([0x01], timestamp: 0, isKeyframe: true)
        try await writer.writeVideo([0x02], timestamp: 33, isKeyframe: false)
        try await writer.writeAudio([0xAA], timestamp: 10)
        let segment = try await writer.close()
        #expect(segment.videoFrameCount == 2)
        #expect(segment.audioFrameCount == 1)
        #expect(segment.format == .flv)
    }

    @Test("keyframe flag: video tag byte high nibble 0x1 for keyframe, 0x2 for inter")
    func keyframeFlag() async throws {
        let path = tempPath()
        defer { cleanup(path) }
        let writer = try FLVWriter(path: path)
        try await writer.writeVideo([0x01], timestamp: 0, isKeyframe: true)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        // Tag data starts at byte 13 (tag type) + 11 (tag header) = byte 24
        // Actually: header(9) + prevTagSize(4) + tagHeader(11) = byte 24
        let videoDataByte = bytes[24]
        // Keyframe: frameType=1 → 0x10, codecID=7 → 0x17
        #expect(videoDataByte == 0x17)
    }
}
