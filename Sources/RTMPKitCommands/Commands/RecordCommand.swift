// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import RTMPKit

/// Publish and record an RTMP stream simultaneously.
///
/// Usage:
///   rtmp-cli record stream.flv --url rtmp://server/app --key key
///   rtmp-cli record stream.flv --url rtmp://server/app --key key --output ./recordings
///   rtmp-cli record stream.flv --url rtmp://server/app --key key --segment 3600
public struct RecordCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Publish an FLV file and record the stream to disk"
    )

    // MARK: - Arguments

    /// FLV file to stream.
    @Argument(help: "Path to FLV file to stream")
    public var file: String

    /// RTMP server URL.
    @Option(name: .long, help: "RTMP server URL")
    public var url: String

    /// Stream key.
    @Option(name: .long, help: "Stream key")
    public var key: String

    /// Output directory for recordings.
    @Option(
        name: .long,
        help: "Output directory for recordings (default: current directory)"
    )
    public var output: String?

    /// Recording format.
    @Option(
        name: .long,
        help: "Recording format: flv, video, audio, all (default: flv)"
    )
    public var format: String?

    /// Segment duration in seconds.
    @Option(name: .long, help: "Segment duration in seconds")
    public var segment: Double?

    /// Maximum total recording size in bytes.
    @Option(name: .long, help: "Maximum total recording size in bytes")
    public var maxSize: Int?

    public init() {}

    public mutating func run() async throws {
        let config = buildRecordingConfig()
        try ensureOutputDirectory(config)

        let reader = try openFLVFile()

        print("Publishing \(file) to \(url)...")
        printOutputDirectory(config)

        let publisher = RTMPPublisher()
        try await publisher.startRecording(configuration: config)

        do {
            try await publisher.publish(url: url, streamKey: key)
        } catch let error as RTMPError {
            print("Error: \(error.description)")
            throw ExitCode.failure
        }

        print("Streaming and recording...")

        do {
            try await streamAndRecord(
                reader: reader, publisher: publisher
            )
        } catch let error as RTMPError {
            print("Error during streaming: \(error.description)")
        } catch {
            print("Error during streaming: \(error)")
        }

        let seg = try await publisher.stopRecording()
        await publisher.disconnect()
        printSummary(seg)
    }

    // MARK: - Private Helpers

    private func ensureOutputDirectory(
        _ config: RecordingConfiguration
    ) throws {
        guard let dir = config.outputDirectory else { return }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: dir, isDirectory: &isDir) {
            do {
                try fm.createDirectory(
                    atPath: dir,
                    withIntermediateDirectories: true
                )
            } catch {
                throw ValidationError(
                    "Output directory does not exist and could not"
                        + " be created: \(dir)"
                )
            }
        }
    }

    private func openFLVFile() throws -> MediaFileReader {
        do {
            return try MediaFileReader(path: file)
        } catch {
            print("Error: Failed to open FLV file: \(error)")
            throw ExitCode.failure
        }
    }

    private func printOutputDirectory(
        _ config: RecordingConfiguration
    ) {
        if let dir = config.outputDirectory {
            print("Recording to: \(dir)/")
        } else {
            print("Recording to: current directory")
        }
    }

    private func printSummary(_ segment: RecordingSegment?) {
        if let segment {
            print("\nRecording complete:")
            print("  File: \(segment.filePath)")
            print(
                "  Duration: "
                    + "\(String(format: "%.1f", segment.duration))s"
            )
            print("  Size: \(segment.fileSize) bytes")
            print(
                "  Frames: \(segment.videoFrameCount) video,"
                    + " \(segment.audioFrameCount) audio"
            )
        } else {
            print("\nRecording complete (no segment produced).")
        }
    }

    private func streamAndRecord(
        reader: MediaFileReader, publisher: RTMPPublisher
    ) async throws {
        var tags = reader.tags()
        var baseTime: UInt64 = 0
        var sentFirstAudio = false
        var sentFirstVideo = false

        while let tag = tags.next() {
            if tag.timestamp > 0 {
                let delayMs = UInt64(tag.timestamp) - baseTime
                if delayMs > 0 {
                    try await Task.sleep(
                        nanoseconds: delayMs * 1_000_000
                    )
                }
                baseTime = UInt64(tag.timestamp)
            }

            if tag.isScript {
                try await publisher.sendDataMessagePayload(tag.data)
            } else if tag.isAudio {
                if !sentFirstAudio && !tag.data.isEmpty {
                    try await publisher.sendAudioConfig(tag.data)
                    sentFirstAudio = true
                } else {
                    try await publisher.sendAudio(
                        tag.data, timestamp: tag.timestamp
                    )
                }
            } else if tag.isVideo {
                if !sentFirstVideo && !tag.data.isEmpty {
                    try await publisher.sendVideoConfig(tag.data)
                    sentFirstVideo = true
                } else {
                    let isKeyframe =
                        !tag.data.isEmpty
                        && (tag.data[0] & 0xF0) == 0x10
                    try await publisher.sendVideo(
                        tag.data,
                        timestamp: tag.timestamp,
                        isKeyframe: isKeyframe
                    )
                }
            }
        }
    }

    /// Build the recording configuration from CLI options.
    internal func buildRecordingConfig() -> RecordingConfiguration {
        let recordingFormat = parseFormat(format)
        return RecordingConfiguration(
            format: recordingFormat,
            outputDirectory: output,
            segmentDuration: segment,
            maxTotalSize: maxSize
        )
    }

    private func parseFormat(
        _ format: String?
    ) -> RecordingConfiguration.Format {
        switch format {
        case "video": .videoElementaryStream
        case "audio": .audioElementaryStream
        case "all": .all
        default: .flv
        }
    }
}
