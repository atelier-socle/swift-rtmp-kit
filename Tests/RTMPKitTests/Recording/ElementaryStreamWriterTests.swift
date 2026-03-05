// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

@Suite("ElementaryStreamWriter")
struct ElementaryStreamWriterTests {

    private func tempPath(_ ext: String) -> String {
        "/tmp/rtmpkit_estest_\(DispatchTime.now().uptimeNanoseconds).\(ext)"
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("init creates a file at the given path")
    func createsFile() async throws {
        let path = tempPath("h264")
        defer { cleanup(path) }
        _ = try ElementaryStreamWriter(path: path, type: .h264)
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("H.264 writer: first 4 bytes are Annex B start code")
    func h264AnnexBStartCode() async throws {
        let path = tempPath("h264")
        defer { cleanup(path) }
        let writer = try ElementaryStreamWriter(path: path, type: .h264)
        try await writer.writeVideo([0x65, 0x88], timestamp: 0)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        #expect(bytes.count >= 4)
        #expect(bytes[0] == 0x00)
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x00)
        #expect(bytes[3] == 0x01)
    }

    @Test("AAC writer: first byte is 0xFF (ADTS syncword high)")
    func aacADTSSyncword() async throws {
        let path = tempPath("aac")
        defer { cleanup(path) }
        let writer = try ElementaryStreamWriter(path: path, type: .aac)
        try await writer.writeAudio([0x01, 0x02, 0x03], timestamp: 0)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        #expect(bytes.count >= 2)
        #expect(bytes[0] == 0xFF)
    }

    @Test("ADTS second byte: 0xF1 (syncword low + MPEG-4 + no CRC)")
    func adtsSecondByte() async throws {
        let path = tempPath("aac")
        defer { cleanup(path) }
        let writer = try ElementaryStreamWriter(path: path, type: .aac)
        try await writer.writeAudio([0x01, 0x02, 0x03], timestamp: 0)
        _ = try await writer.close()

        let bytes = [UInt8](FileManager.default.contents(atPath: path) ?? Data())
        #expect(bytes[1] == 0xF1)
    }

    @Test("frameCount increments after each write")
    func frameCountIncrements() async throws {
        let path = tempPath("h264")
        defer { cleanup(path) }
        let writer = try ElementaryStreamWriter(path: path, type: .h264)
        try await writer.writeVideo([0x01], timestamp: 0)
        try await writer.writeVideo([0x02], timestamp: 33)
        let count = await writer.frameCount
        #expect(count == 2)
        _ = try await writer.close()
    }

    @Test("close returns valid RecordingSegment")
    func closeReturnsSegment() async throws {
        let path = tempPath("h264")
        defer { cleanup(path) }
        let writer = try ElementaryStreamWriter(path: path, type: .h264)
        try await writer.writeVideo([0x01], timestamp: 0)
        try await writer.writeVideo([0x02], timestamp: 1000)
        let segment = try await writer.close()
        #expect(segment.format == .videoElementaryStream)
        #expect(segment.videoFrameCount == 2)
        #expect(segment.duration == 1.0)
    }
}
