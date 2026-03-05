// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

@Suite("StreamRecorder")
struct StreamRecorderTests {

    private func tempDir() -> String {
        let dir = "/tmp/rtmpkit_rectest_\(DispatchTime.now().uptimeNanoseconds)"
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        return dir
    }

    private func cleanup(_ dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }

    @Test("initial state is .idle")
    func initialState() async {
        let config = RecordingConfiguration(format: .flv)
        let recorder = StreamRecorder(configuration: config)
        let state = await recorder.state
        #expect(state == .idle)
    }

    @Test("start transitions to .recording")
    func startRecording() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir, baseFilename: "test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()
        let state = await recorder.state
        #expect(state == .recording)
        _ = try await recorder.stop()
    }

    @Test("pause transitions to .paused")
    func pauseRecording() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir, baseFilename: "test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()
        await recorder.pause()
        let state = await recorder.state
        #expect(state == .paused)
        _ = try await recorder.stop()
    }

    @Test("resume transitions to .recording")
    func resumeRecording() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir, baseFilename: "test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()
        await recorder.pause()
        await recorder.resume()
        let state = await recorder.state
        #expect(state == .recording)
        _ = try await recorder.stop()
    }

    @Test("stop transitions to .stopped")
    func stopRecording() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir, baseFilename: "test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()
        _ = try await recorder.stop()
        let state = await recorder.state
        #expect(state == .stopped)
    }

    @Test("frames while paused are discarded")
    func pausedDiscards() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir, baseFilename: "test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()
        try await recorder.writeVideo([0x01], timestamp: 0, isKeyframe: true)
        await recorder.pause()
        try await recorder.writeVideo([0x02], timestamp: 33, isKeyframe: false)
        await recorder.resume()
        let segment = try await recorder.stop()
        #expect(segment?.videoFrameCount == 1)
    }

    @Test("writeVideo while recording increases totalBytesWritten")
    func videoBytesIncrease() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir, baseFilename: "test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()
        try await recorder.writeVideo([0x01, 0x02], timestamp: 0, isKeyframe: true)
        let bytes = await recorder.totalBytesWritten
        #expect(bytes > 0)
        _ = try await recorder.stop()
    }

    @Test("writeAudio while recording increases totalBytesWritten")
    func audioBytesIncrease() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir, baseFilename: "test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()
        try await recorder.writeAudio([0xAA, 0xBB], timestamp: 0)
        let bytes = await recorder.totalBytesWritten
        #expect(bytes > 0)
        _ = try await recorder.stop()
    }

    @Test("writeVideo while idle is a no-op")
    func writeWhileIdleNoOp() async throws {
        let config = RecordingConfiguration(format: .flv)
        let recorder = StreamRecorder(configuration: config)
        // Should not crash
        try await recorder.writeVideo([0x01], timestamp: 0, isKeyframe: true)
        let bytes = await recorder.totalBytesWritten
        #expect(bytes == 0)
    }

    @Test("stop returns RecordingSegment with correct frame counts")
    func stopReturnsCorrectCounts() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir, baseFilename: "test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()
        for i in 0..<5 {
            try await recorder.writeVideo(
                [0x01], timestamp: UInt32(i * 33), isKeyframe: i == 0
            )
        }
        for i in 0..<3 {
            try await recorder.writeAudio(
                [0xAA], timestamp: UInt32(i * 23)
            )
        }
        let segment = try await recorder.stop()
        #expect(segment?.videoFrameCount == 5)
        #expect(segment?.audioFrameCount == 3)
    }

    @Test("segment rotation: completedSegments grows")
    func segmentRotation() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir,
            baseFilename: "test", segmentDuration: 1.0
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()

        // Write 3 seconds of frames (30fps = 90 frames)
        for i in 0..<90 {
            try await recorder.writeVideo(
                [0x01], timestamp: UInt32(i * 33), isKeyframe: i % 30 == 0
            )
        }

        let segments = await recorder.completedSegments
        #expect(segments.count >= 2)
        _ = try await recorder.stop()
    }

    @Test("events stream emits .started when recording begins")
    func startedEvent() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: dir, baseFilename: "test"
        )
        let recorder = StreamRecorder(configuration: config)

        let eventStream = await recorder.events
        let eventTask = Task {
            var events: [RecordingEvent] = []
            for await event in eventStream {
                events.append(event)
                if events.count >= 1 { break }
            }
            return events
        }

        try await recorder.start()

        let events = await eventTask.value
        guard let first = events.first else {
            Issue.record("No events received")
            _ = try await recorder.stop()
            return
        }
        if case .started = first {
            // Expected
        } else {
            Issue.record("Expected .started event")
        }
        _ = try await recorder.stop()
    }
}
