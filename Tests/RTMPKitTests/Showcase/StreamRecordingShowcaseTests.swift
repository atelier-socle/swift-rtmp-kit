// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

// MARK: - Suite 1: FLV Recording

@Suite("Stream Recording Showcase — FLV Recording")
struct FLVRecordingShowcaseTests {

    private func tempDir() -> String {
        let dir = "/tmp/rtmpkit_showcase_\(DispatchTime.now().uptimeNanoseconds)"
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        return dir
    }

    private func cleanup(_ dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }

    @Test("Record a live stream to FLV")
    func recordToFLV() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }

        let config = RecordingConfiguration(
            format: .flv,
            outputDirectory: dir,
            baseFilename: "stream"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()

        let videoBytes: [UInt8] = [0x65, 0x88, 0x84, 0x00]
        let audioBytes: [UInt8] = [0x01, 0x02, 0x03]

        for i in 0..<100 {
            try await recorder.writeVideo(
                videoBytes,
                timestamp: UInt32(i * 33),
                isKeyframe: i % 30 == 0
            )
            try await recorder.writeAudio(
                audioBytes, timestamp: UInt32(i * 23)
            )
        }

        let segment = try await recorder.stop()
        #expect(segment?.videoFrameCount == 100)
        #expect(segment?.audioFrameCount == 100)
        #expect(segment?.fileSize ?? 0 > 0)
    }

    @Test("FLV file has valid header structure")
    func validFLVHeader() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }

        let config = RecordingConfiguration(
            format: .flv,
            outputDirectory: dir,
            baseFilename: "header_test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()
        try await recorder.writeVideo(
            [0x01], timestamp: 0, isKeyframe: true
        )
        let segment = try await recorder.stop()

        guard let path = segment?.filePath else {
            Issue.record("No segment returned")
            return
        }
        let data = FileManager.default.contents(atPath: path) ?? Data()
        let bytes = [UInt8](data)

        // FLV signature
        #expect(bytes[0] == 0x46)  // 'F'
        #expect(bytes[1] == 0x4C)  // 'L'
        #expect(bytes[2] == 0x56)  // 'V'
        #expect(bytes[3] == 0x01)  // version 1
        #expect(bytes[4] == 0x05)  // audio + video flags
    }

    @Test("Segmented recording creates multiple files")
    func segmentedRecording() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }

        let config = RecordingConfiguration(
            format: .flv,
            outputDirectory: dir,
            baseFilename: "segmented",
            segmentDuration: 1.0
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()

        // Write 3 seconds of video at ~30fps
        for i in 0..<90 {
            try await recorder.writeVideo(
                [0x01], timestamp: UInt32(i * 33),
                isKeyframe: i % 30 == 0
            )
        }

        let segments = await recorder.completedSegments
        #expect(segments.count >= 2)
        _ = try await recorder.stop()
    }

    @Test("Recording paused: no frames written")
    func pausedNoFrames() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }

        let config = RecordingConfiguration(
            format: .flv,
            outputDirectory: dir,
            baseFilename: "pause_test"
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()

        // Write 10 frames
        for i in 0..<10 {
            try await recorder.writeVideo(
                [0x01], timestamp: UInt32(i * 33), isKeyframe: i == 0
            )
            try await recorder.writeAudio(
                [0xAA], timestamp: UInt32(i * 23)
            )
        }

        // Pause and write 10 more (should be discarded)
        await recorder.pause()
        for i in 10..<20 {
            try await recorder.writeVideo(
                [0x01], timestamp: UInt32(i * 33), isKeyframe: false
            )
            try await recorder.writeAudio(
                [0xAA], timestamp: UInt32(i * 23)
            )
        }

        await recorder.resume()
        let segment = try await recorder.stop()
        #expect(segment?.videoFrameCount == 10)
        #expect(segment?.audioFrameCount == 10)
    }

    @Test("Size limit stops recording")
    func sizeLimitStops() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }

        let config = RecordingConfiguration(
            format: .flv,
            outputDirectory: dir,
            baseFilename: "limit_test",
            maxTotalSize: 1024
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()

        // Write frames until limit is reached
        for i in 0..<200 {
            let state = await recorder.state
            guard state == .recording else { break }
            try await recorder.writeVideo(
                [0x01, 0x02, 0x03, 0x04, 0x05],
                timestamp: UInt32(i * 33),
                isKeyframe: i % 30 == 0
            )
        }

        let state = await recorder.state
        #expect(state == .stopped)
    }
}

// MARK: - Suite 2: Publisher Integration

/// Build a scripted server response sequence for a successful publish.
private func makePublishScript(streamID: Double = 1) -> [RTMPMessage] {
    [
        RTMPMessage(
            command: .result(
                transactionID: 1,
                properties: nil,
                information: .object([
                    ("code", .string("NetConnection.Connect.Success"))
                ])
            )),
        RTMPMessage(
            command: .result(
                transactionID: 4,
                properties: nil,
                information: .number(streamID)
            )),
        RTMPMessage(
            command: .onStatus(
                information: .object([
                    ("code", .string("NetStream.Publish.Start")),
                    ("description", .string("Publishing"))
                ])))
    ]
}

@Suite("Stream Recording Showcase — Publisher Integration")
struct RecordingPublisherShowcaseTests {

    private func tempDir() -> String {
        let dir = "/tmp/rtmpkit_pubrectest_\(DispatchTime.now().uptimeNanoseconds)"
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        return dir
    }

    private func cleanup(_ dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }

    @Test("Publisher records while publishing")
    func publisherRecords() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }

        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        try await publisher.startRecording(
            configuration: RecordingConfiguration(
                format: .flv,
                outputDirectory: dir,
                baseFilename: "pub_test"
            )
        )
        try await publisher.publish(
            configuration: RTMPConfiguration(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
        )

        for i in 0..<10 {
            try await publisher.sendVideo(
                [0x01], timestamp: UInt32(i * 33), isKeyframe: i == 0
            )
            try await publisher.sendAudio(
                [0xAA], timestamp: UInt32(i * 23)
            )
        }

        let segment = try await publisher.stopRecording()
        #expect(segment != nil)
        #expect(segment?.videoFrameCount ?? 0 > 0)
        #expect(segment?.audioFrameCount ?? 0 > 0)

        await publisher.disconnect()
    }

    @Test("Recording starts before connect")
    func recordingBeforeConnect() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }

        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        try await publisher.startRecording(
            configuration: RecordingConfiguration(
                format: .flv,
                outputDirectory: dir,
                baseFilename: "before_test"
            )
        )
        let recording = await publisher.isRecording
        #expect(recording)

        try await publisher.publish(
            configuration: RTMPConfiguration(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
        )

        try await publisher.sendVideo(
            [0x01], timestamp: 0, isKeyframe: true
        )

        let segment = try await publisher.stopRecording()
        #expect(segment != nil)

        await publisher.disconnect()
    }

    @Test("recordingEvent forwarded to RTMPEvent stream")
    func recordingEventForwarded() async throws {
        let dir = tempDir()
        defer { cleanup(dir) }

        let mock = MockTransport()
        await mock.setScriptedMessages(makePublishScript())
        let publisher = RTMPPublisher(transport: mock)

        let eventStream = await publisher.events
        let eventTask = Task {
            var collected: [RTMPEvent] = []
            for await event in eventStream {
                collected.append(event)
                if case .recordingEvent = event { break }
            }
            return collected
        }

        try await publisher.startRecording(
            configuration: RecordingConfiguration(
                format: .flv,
                outputDirectory: dir,
                baseFilename: "event_test"
            )
        )

        // Wait for event propagation
        try await Task.sleep(for: .milliseconds(50))
        eventTask.cancel()

        let recording = await publisher.isRecording
        #expect(recording)

        _ = try await publisher.stopRecording()
        await publisher.disconnect()
    }

    @Test("Stop recording without starting returns nil")
    func stopWithoutStart() async throws {
        let publisher = RTMPPublisher(transport: MockTransport())
        let segment = try await publisher.stopRecording()
        #expect(segment == nil)
    }
}
