// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

// MARK: - FLVWriter Script Tag and Error Paths

@Suite("FLVWriter — Script Tag and Error Paths")
struct FLVWriterCoverageTests {

    @Test("writeScriptTag writes metadata to FLV file")
    func writeScriptTag() async throws {
        let tmpDir = NSTemporaryDirectory()
        let path = tmpDir + "test_script_\(UUID().uuidString).flv"
        let writer = try FLVWriter(path: path)
        try await writer.writeScriptTag(
            name: "onMetaData",
            metadata: ["width": .number(1920), "height": .number(1080)]
        )
        _ = try await writer.close()

        let data = FileManager.default.contents(atPath: path)
        #expect(data != nil)
        #expect((data?.count ?? 0) > 13)

        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("init with invalid path throws error")
    func initInvalidPathThrows() {
        #expect(throws: Error.self) {
            _ = try FLVWriter(path: "/nonexistent/dir/file.flv")
        }
    }
}

// MARK: - ElementaryStreamWriter Error Paths

@Suite("ElementaryStreamWriter — Error Paths")
struct ElementaryStreamWriterCoverageTests {

    @Test("init with invalid path throws error")
    func initInvalidPathThrows() {
        #expect(throws: Error.self) {
            _ = try ElementaryStreamWriter(
                path: "/nonexistent/dir/out.h264", type: .h264
            )
        }
    }
}

// MARK: - StreamRecorder Metadata

@Suite("StreamRecorder — Metadata Write")
struct StreamRecorderCoverageTests {

    @Test("writeMetadata writes to recording")
    func writeMetadataToRecording() async throws {
        let tmpDir =
            NSTemporaryDirectory()
            + "rec_\(UUID().uuidString)/"
        try FileManager.default.createDirectory(
            atPath: tmpDir, withIntermediateDirectories: true
        )
        let config = RecordingConfiguration(
            format: .flv, outputDirectory: tmpDir
        )
        let recorder = StreamRecorder(configuration: config)
        try await recorder.start()

        var metadata = StreamMetadata()
        metadata.videoBitrate = 2500
        metadata.audioBitrate = 128
        metadata.width = 1920
        metadata.height = 1080
        try await recorder.writeMetadata(metadata)

        _ = try await recorder.stop()
        try? FileManager.default.removeItem(atPath: tmpDir)
    }
}

// MARK: - RTMPStreamDVR Metadata

@Suite("RTMPStreamDVR — Metadata")
struct RTMPStreamDVRMetadataCoverageTests {

    @Test("recordMetadata is no-op when idle")
    func recordMetadataIdleNoOp() async throws {
        let tmpDir =
            NSTemporaryDirectory()
            + "dvr_idle_\(UUID().uuidString)/"
        try FileManager.default.createDirectory(
            atPath: tmpDir, withIntermediateDirectories: true
        )
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                format: .flv, outputDirectory: tmpDir
            )
        )
        try await dvr.recordMetadata(StreamMetadata())
        try? FileManager.default.removeItem(atPath: tmpDir)
    }

    @Test("recordMetadata writes metadata when recording")
    func recordMetadataWhileRecording() async throws {
        let tmpDir =
            NSTemporaryDirectory()
            + "dvr_rec_\(UUID().uuidString)/"
        try FileManager.default.createDirectory(
            atPath: tmpDir, withIntermediateDirectories: true
        )
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                format: .flv, outputDirectory: tmpDir
            )
        )
        try await dvr.start()
        try await dvr.recordMetadata(StreamMetadata())
        _ = try await dvr.stop()
        try? FileManager.default.removeItem(atPath: tmpDir)
    }
}

// MARK: - RTMPStreamRelay Init and Metadata

@Suite("RTMPStreamRelay — Init and Metadata")
struct RTMPStreamRelayCoverageTests {

    @Test("public init creates relay with NIO transport")
    func publicInit() async {
        let relay = RTMPStreamRelay(destinations: [])
        let state = await relay.state
        #expect(state == .idle)
    }

    @Test("activeDestinationCount returns 0 when idle")
    func activeCountZeroWhenIdle() async throws {
        let relay = RTMPStreamRelay(
            destinations: [],
            transportFactory: { _ in MockTransport() }
        )
        let count = await relay.activeDestinationCount
        #expect(count == 0)
    }

    @Test("relayMetadata is no-op when not relaying")
    func relayMetadataIdleNoOp() async {
        let relay = RTMPStreamRelay(
            destinations: [],
            transportFactory: { _ in MockTransport() }
        )
        await relay.relayMetadata(StreamMetadata())
    }

    @Test("relayMetadata sends metadata when relaying")
    func relayMetadataWhileRelaying() async throws {
        let relay = RTMPStreamRelay(
            destinations: [],
            transportFactory: { _ in MockTransport() }
        )
        try await relay.start()
        await relay.relayMetadata(StreamMetadata())
        await relay.stop()
    }
}
