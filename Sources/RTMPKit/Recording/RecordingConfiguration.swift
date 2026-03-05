// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for local stream recording.
///
/// Controls the output format, file naming, segmentation, and size limits
/// for recording a live stream to disk.
public struct RecordingConfiguration: Sendable {

    /// Output format for the recording.
    public enum Format: String, Sendable, CaseIterable {

        /// Flash Video container (.flv). Contains both audio and video.
        case flv

        /// Raw H.264/HEVC elementary stream (.h264 / .hevc).
        case videoElementaryStream

        /// Raw AAC/Opus elementary stream (.aac / .opus).
        case audioElementaryStream

        /// Both FLV container and separate elementary streams.
        case all
    }

    /// Output format. Default: `.flv`.
    public var format: Format

    /// Directory path where recordings are saved.
    /// If nil, uses the current working directory.
    public var outputDirectory: String?

    /// Base filename (without extension). If nil, auto-generates from timestamp.
    /// e.g. "my_stream" produces "my_stream.flv", "my_stream.h264".
    public var baseFilename: String?

    /// Maximum segment duration in seconds. nil = no segmentation (single file).
    /// When set, recording is split into segments of this duration.
    public var segmentDuration: Double?

    /// Maximum total recording size in bytes. nil = unlimited.
    /// Recording stops gracefully when this limit is reached.
    public var maxTotalSize: Int?

    /// Whether to write a JSON sidecar file alongside each segment
    /// containing timing, codec, and quality metadata.
    public var writeSidecar: Bool

    /// Creates a recording configuration.
    ///
    /// - Parameters:
    ///   - format: Output format. Default: `.flv`.
    ///   - outputDirectory: Directory path for output files. Default: nil (current directory).
    ///   - baseFilename: Base filename without extension. Default: nil (auto-generated).
    ///   - segmentDuration: Segment duration in seconds. Default: nil (no segmentation).
    ///   - maxTotalSize: Maximum total bytes. Default: nil (unlimited).
    ///   - writeSidecar: Write JSON sidecar file. Default: false.
    public init(
        format: Format = .flv,
        outputDirectory: String? = nil,
        baseFilename: String? = nil,
        segmentDuration: Double? = nil,
        maxTotalSize: Int? = nil,
        writeSidecar: Bool = false
    ) {
        self.format = format
        self.outputDirectory = outputDirectory
        self.baseFilename = baseFilename
        self.segmentDuration = segmentDuration
        self.maxTotalSize = maxTotalSize
        self.writeSidecar = writeSidecar
    }
}

extension RecordingConfiguration {

    /// Record FLV to the current directory with auto-generated filename.
    public static let `default` = RecordingConfiguration()

    /// Record FLV with segmentation.
    ///
    /// - Parameters:
    ///   - outputDirectory: Directory path for output files.
    ///   - segmentDuration: Segment duration in seconds. Default: 3600 (1 hour).
    /// - Returns: A segmented recording configuration.
    public static func segmented(
        outputDirectory: String,
        segmentDuration: Double = 3600
    ) -> RecordingConfiguration {
        RecordingConfiguration(
            format: .flv,
            outputDirectory: outputDirectory,
            segmentDuration: segmentDuration
        )
    }
}
