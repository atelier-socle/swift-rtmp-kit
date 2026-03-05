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

        print("Publishing \(file) to \(url)...")
        if let dir = config.outputDirectory {
            print("Recording to: \(dir)/")
        } else {
            print("Recording to: current directory")
        }

        let publisher = RTMPPublisher()
        try await publisher.startRecording(configuration: config)
        try await publisher.publish(
            url: url, streamKey: key
        )

        print("Streaming and recording... Press Ctrl+C to stop.")

        // Keep running until interrupted
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let source = DispatchSource.makeSignalSource(
                signal: SIGINT, queue: .main
            )
            source.setEventHandler {
                source.cancel()
                continuation.resume()
            }
            source.resume()
        }

        let segment = try await publisher.stopRecording()
        await publisher.disconnect()

        if let segment {
            print("\nRecording complete:")
            print("  File: \(segment.filePath)")
            print("  Duration: \(String(format: "%.1f", segment.duration))s")
            print("  Size: \(segment.fileSize) bytes")
            print(
                "  Frames: \(segment.videoFrameCount) video, \(segment.audioFrameCount) audio"
            )
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
