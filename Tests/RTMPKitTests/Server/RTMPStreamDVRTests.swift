// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

@Suite("RTMPStreamDVR")
struct RTMPStreamDVRTests {

    private func makeTempDir() -> String {
        let path = "/tmp/rtmpkit_dvr_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(
            atPath: path, withIntermediateDirectories: true
        )
        return path
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("Initial state is .idle")
    func initialState() async {
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration()
        )
        let state = await dvr.state
        #expect(state == .idle)
    }

    @Test("start() transitions to .recording")
    func startTransition() async throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                outputDirectory: tempDir
            )
        )
        try await dvr.start()
        let state = await dvr.state
        #expect(state == .recording)
    }

    @Test("stop() transitions to .stopped and returns segment")
    func stopTransition() async throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                outputDirectory: tempDir
            )
        )
        try await dvr.start()
        // Write at least one frame so there's data
        try await dvr.recordVideo(
            [0x17, 0x01, 0x00, 0x00, 0x00], timestamp: 0,
            isKeyframe: true
        )
        let segment = try await dvr.stop()
        let state = await dvr.state
        #expect(state == .stopped)
        #expect(segment != nil)
    }

    @Test("recordVideo increases totalBytesWritten")
    func recordVideoIncreases() async throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                outputDirectory: tempDir
            )
        )
        try await dvr.start()
        try await dvr.recordVideo(
            [0x17, 0x01, 0x00, 0x00, 0x00, 0x01],
            timestamp: 0, isKeyframe: true
        )
        let bytes = await dvr.totalBytesWritten
        #expect(bytes > 0)
        _ = try await dvr.stop()
    }

    @Test("recordVideo while idle is a no-op")
    func recordWhileIdle() async throws {
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration()
        )
        try await dvr.recordVideo(
            [0x17, 0x01], timestamp: 0, isKeyframe: true
        )
        let bytes = await dvr.totalBytesWritten
        #expect(bytes == 0)
    }

    @Test("completedSegments grows after segmented stop")
    func segmentedRecording() async throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                outputDirectory: tempDir,
                segmentDuration: 0.5
            )
        )
        try await dvr.start()
        // Write frames spanning multiple segments
        for i in 0..<20 {
            try await dvr.recordVideo(
                [0x17, 0x01, 0x00, 0x00, 0x00],
                timestamp: UInt32(i * 100), isKeyframe: i == 0
            )
            try await dvr.recordAudio(
                [0xAF, 0x01, 0xAA],
                timestamp: UInt32(i * 100)
            )
        }
        _ = try await dvr.stop()
        let segments = await dvr.completedSegments
        // With 0.5s segments and 2s total, expect multiple segments
        #expect(segments.count >= 1)
    }
}
