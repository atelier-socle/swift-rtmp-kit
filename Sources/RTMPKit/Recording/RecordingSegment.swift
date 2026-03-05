// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Metadata about a completed recording segment.
///
/// Created by ``FLVWriter``, ``ElementaryStreamWriter``, or
/// ``StreamRecorder`` when a segment is finalized.
public struct RecordingSegment: Sendable {

    /// Full path to the recorded file.
    public let filePath: String

    /// Recording format of this segment.
    public let format: RecordingConfiguration.Format

    /// Duration of the segment in seconds.
    public let duration: Double

    /// Size of the file in bytes.
    public let fileSize: Int

    /// Number of video frames written.
    public let videoFrameCount: Int

    /// Number of audio frames written.
    public let audioFrameCount: Int

    /// Start timestamp (stream time, milliseconds).
    public let startTimestamp: UInt32

    /// End timestamp (stream time, milliseconds).
    public let endTimestamp: UInt32

    /// Wall-clock time when recording started (ContinuousClock seconds).
    public let recordingStarted: Double

    /// Wall-clock time when recording ended (ContinuousClock seconds).
    public let recordingEnded: Double

    /// Creates a recording segment.
    ///
    /// - Parameters:
    ///   - filePath: Full path to the recorded file.
    ///   - format: Recording format.
    ///   - duration: Duration in seconds.
    ///   - fileSize: File size in bytes.
    ///   - videoFrameCount: Number of video frames.
    ///   - audioFrameCount: Number of audio frames.
    ///   - startTimestamp: Start timestamp in milliseconds.
    ///   - endTimestamp: End timestamp in milliseconds.
    ///   - recordingStarted: Wall-clock start time.
    ///   - recordingEnded: Wall-clock end time.
    public init(
        filePath: String,
        format: RecordingConfiguration.Format,
        duration: Double,
        fileSize: Int,
        videoFrameCount: Int,
        audioFrameCount: Int,
        startTimestamp: UInt32,
        endTimestamp: UInt32,
        recordingStarted: Double,
        recordingEnded: Double
    ) {
        self.filePath = filePath
        self.format = format
        self.duration = duration
        self.fileSize = fileSize
        self.videoFrameCount = videoFrameCount
        self.audioFrameCount = audioFrameCount
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.recordingStarted = recordingStarted
        self.recordingEnded = recordingEnded
    }
}
