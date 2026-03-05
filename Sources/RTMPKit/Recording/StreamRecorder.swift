// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch
import Foundation

/// Records a live RTMP stream to local files while publishing.
///
/// Can be started/stopped independently of the publisher connection.
/// Supports FLV container format, elementary streams, and segmented recording.
public actor StreamRecorder {

    // MARK: - State

    /// Recording state.
    public enum State: Sendable, Equatable {

        /// Not yet started.
        case idle

        /// Actively recording frames.
        case recording

        /// Recording paused — frames are discarded.
        case paused

        /// Recording stopped and finalized.
        case stopped
    }

    /// Current recorder state.
    public private(set) var state: State = .idle

    /// Completed segments (grows during segmented recording).
    public private(set) var completedSegments: [RecordingSegment] = []

    /// Total bytes written across all segments.
    public private(set) var totalBytesWritten: Int = 0

    /// Stream of recording events.
    public var events: AsyncStream<RecordingEvent> {
        eventStream
    }

    // MARK: - Private

    private let configuration: RecordingConfiguration
    private var flvWriter: FLVWriter?
    private var videoESWriter: ElementaryStreamWriter?
    private var audioESWriter: ElementaryStreamWriter?
    private var segmentIndex: Int = 0
    private var segmentStartTimestamp: UInt32 = 0

    private let eventStream: AsyncStream<RecordingEvent>
    private let eventContinuation: AsyncStream<RecordingEvent>.Continuation

    // MARK: - Lifecycle

    /// Creates a new stream recorder.
    ///
    /// - Parameter configuration: Recording configuration.
    public init(configuration: RecordingConfiguration) {
        self.configuration = configuration
        let (stream, continuation) = AsyncStream.makeStream(
            of: RecordingEvent.self
        )
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    /// Start recording. Creates output files immediately.
    ///
    /// - Throws: If a file cannot be created at the configured path.
    public func start() async throws {
        guard state == .idle || state == .stopped else { return }

        segmentIndex = 0
        try await openWriters()

        state = .recording
        let filePath = currentFilePath(extension: "flv")
        eventContinuation.yield(.started(filePath: filePath))
    }

    /// Pause recording. Frames received while paused are discarded.
    public func pause() {
        guard state == .recording else { return }
        state = .paused
    }

    /// Resume recording after pause.
    public func resume() {
        guard state == .paused else { return }
        state = .recording
    }

    /// Stop recording. Closes and finalizes all open files.
    ///
    /// - Returns: The final segment, or nil if nothing was written.
    @discardableResult
    public func stop() async throws -> RecordingSegment? {
        guard state == .recording || state == .paused else {
            return nil
        }

        let segment = try await closeWriters()
        state = .stopped
        eventContinuation.yield(.stopped(segment))
        eventContinuation.finish()
        return segment
    }

    // MARK: - Frame Ingestion

    /// Write a video frame. No-op if not recording.
    ///
    /// - Parameters:
    ///   - data: Raw video frame data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    ///   - isKeyframe: Whether this is a keyframe.
    /// - Throws: If writing fails.
    public func writeVideo(
        _ data: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) async throws {
        guard state == .recording else { return }

        try await flvWriter?.writeVideo(
            data, timestamp: timestamp, isKeyframe: isKeyframe
        )
        try await videoESWriter?.writeVideo(data, timestamp: timestamp)

        await updateBytesWritten()
        try await checkSegmentRotation(currentTimestamp: timestamp)
        try await checkSizeLimit()
    }

    /// Write an audio frame. No-op if not recording.
    ///
    /// - Parameters:
    ///   - data: Raw audio frame data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    /// - Throws: If writing fails.
    public func writeAudio(
        _ data: [UInt8], timestamp: UInt32
    ) async throws {
        guard state == .recording else { return }

        try await flvWriter?.writeAudio(data, timestamp: timestamp)
        try await audioESWriter?.writeAudio(data, timestamp: timestamp)

        await updateBytesWritten()
        try await checkSegmentRotation(currentTimestamp: timestamp)
        try await checkSizeLimit()
    }

    /// Write stream metadata (written as FLV script tag).
    ///
    /// - Parameter metadata: The stream metadata to write.
    /// - Throws: If writing fails.
    public func writeMetadata(
        _ metadata: StreamMetadata
    ) async throws {
        guard state == .recording else { return }

        var amfData: [String: AMF0Value] = [:]
        if let width = metadata.width {
            amfData["width"] = .number(Double(width))
        }
        if let height = metadata.height {
            amfData["height"] = .number(Double(height))
        }
        if let videoBitrate = metadata.videoBitrate {
            amfData["videodatarate"] = .number(Double(videoBitrate) / 1000.0)
        }
        if let audioBitrate = metadata.audioBitrate {
            amfData["audiodatarate"] = .number(Double(audioBitrate) / 1000.0)
        }
        if let frameRate = metadata.frameRate {
            amfData["framerate"] = .number(frameRate)
        }

        try await flvWriter?.writeScriptTag(
            name: "onMetaData", metadata: amfData
        )
    }

    // MARK: - Segmentation

    /// Check if the current segment should be rotated and rotate if needed.
    ///
    /// - Parameter currentTimestamp: Current frame timestamp in milliseconds.
    /// - Throws: If file operations fail.
    internal func checkSegmentRotation(
        currentTimestamp: UInt32
    ) async throws {
        guard let segmentDuration = configuration.segmentDuration else {
            return
        }

        let elapsed = currentTimestamp - segmentStartTimestamp
        let thresholdMs = UInt32(segmentDuration * 1000)

        guard elapsed >= thresholdMs else { return }

        // Close current segment
        if let segment = try await closeWriters() {
            completedSegments.append(segment)
            eventContinuation.yield(.segmentCompleted(segment))
        }

        // Open new segment
        segmentIndex += 1
        segmentStartTimestamp = currentTimestamp
        try await openWriters()
    }

    // MARK: - Private Helpers

    private func openWriters() async throws {
        let format = configuration.format

        if format == .flv || format == .all {
            let path = currentFilePath(extension: "flv")
            flvWriter = try FLVWriter(path: path)
        }

        if format == .videoElementaryStream || format == .all {
            let path = currentFilePath(extension: "h264")
            videoESWriter = try ElementaryStreamWriter(
                path: path, type: .h264
            )
        }

        if format == .audioElementaryStream || format == .all {
            let path = currentFilePath(extension: "aac")
            audioESWriter = try ElementaryStreamWriter(
                path: path, type: .aac
            )
        }
    }

    private func closeWriters() async throws -> RecordingSegment? {
        var segment: RecordingSegment?

        if let writer = flvWriter {
            segment = try await writer.close()
            flvWriter = nil
        }

        if let writer = videoESWriter {
            let seg = try await writer.close()
            if segment == nil { segment = seg }
            videoESWriter = nil
        }

        if let writer = audioESWriter {
            let seg = try await writer.close()
            if segment == nil { segment = seg }
            audioESWriter = nil
        }

        return segment
    }

    private func currentFilePath(extension ext: String) -> String {
        let dir = configuration.outputDirectory ?? "."
        let base = configuration.baseFilename ?? generateFilename()

        if segmentIndex > 0 {
            return "\(dir)/\(base)_\(segmentIndex).\(ext)"
        }
        return "\(dir)/\(base).\(ext)"
    }

    private func generateFilename() -> String {
        let time = DispatchTime.now().uptimeNanoseconds
        return "recording_\(time)"
    }

    private func updateBytesWritten() async {
        var total = 0
        for segment in completedSegments {
            total += segment.fileSize
        }
        if let writer = flvWriter {
            total += await writer.bytesWritten
        }
        if let writer = videoESWriter {
            total += await writer.bytesWritten
        }
        if let writer = audioESWriter {
            total += await writer.bytesWritten
        }
        totalBytesWritten = total
    }

    private func checkSizeLimit() async throws {
        guard let maxSize = configuration.maxTotalSize else { return }
        guard totalBytesWritten >= maxSize else { return }

        eventContinuation.yield(
            .sizeLimitReached(totalBytes: totalBytesWritten)
        )
        _ = try await stop()
    }
}

/// Events emitted by ``StreamRecorder``.
public enum RecordingEvent: Sendable {

    /// Recording started successfully.
    case started(filePath: String)

    /// A segment was completed and a new one started.
    case segmentCompleted(RecordingSegment)

    /// Recording stopped. Contains the final segment if any data was written.
    case stopped(RecordingSegment?)

    /// An error occurred during recording (disk full, permission denied, etc.).
    case error(Error)

    /// Size limit reached — recording stopped automatically.
    case sizeLimitReached(totalBytes: Int)
}
