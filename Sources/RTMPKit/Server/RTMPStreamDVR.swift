// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Records an ingest stream to local storage as it arrives at the server.
///
/// Attach to an ``RTMPServer`` via ``RTMPServer/attachDVR(_:toStream:)``
/// to DVR-record ingest frames.
///
/// ## Usage
/// ```swift
/// let dvr = RTMPStreamDVR(configuration: RecordingConfiguration(
///     format: .flv,
///     outputDirectory: "/tmp/dvr"
/// ))
/// try dvr.start()
/// try dvr.recordVideo(videoBytes, timestamp: 0, isKeyframe: true)
/// let segment = try dvr.stop()
/// ```
public actor RTMPStreamDVR {

    // MARK: - State

    /// DVR lifecycle states.
    public enum State: Sendable, Equatable {
        /// DVR has not been started.
        case idle
        /// DVR is actively recording.
        case recording
        /// DVR has been stopped.
        case stopped
    }

    /// Current DVR state.
    public private(set) var state: State

    // MARK: - Private

    private let recorder: StreamRecorder

    // MARK: - Init

    /// Creates a new DVR recorder.
    ///
    /// - Parameter configuration: Recording configuration for the
    ///   underlying ``StreamRecorder``.
    public init(configuration: RecordingConfiguration) {
        self.recorder = StreamRecorder(configuration: configuration)
        self.state = .idle
    }

    // MARK: - Lifecycle

    /// Start DVR recording.
    ///
    /// - Throws: If the output files cannot be created.
    public func start() async throws {
        guard state == .idle else { return }
        try await recorder.start()
        state = .recording
    }

    /// Stop DVR recording.
    ///
    /// - Returns: The final recording segment, or nil if nothing was written.
    @discardableResult
    public func stop() async throws -> RecordingSegment? {
        guard state == .recording else { return nil }
        let segment = try await recorder.stop()
        state = .stopped
        return segment
    }

    // MARK: - Frame Ingestion

    /// Record a video frame.
    ///
    /// No-op if DVR is not in `.recording` state.
    ///
    /// - Parameters:
    ///   - data: Raw video frame data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    ///   - isKeyframe: Whether this is a keyframe.
    /// - Throws: If writing fails.
    public func recordVideo(
        _ data: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) async throws {
        guard state == .recording else { return }
        try await recorder.writeVideo(
            data, timestamp: timestamp, isKeyframe: isKeyframe
        )
    }

    /// Record an audio frame.
    ///
    /// No-op if DVR is not in `.recording` state.
    ///
    /// - Parameters:
    ///   - data: Raw audio frame data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    /// - Throws: If writing fails.
    public func recordAudio(
        _ data: [UInt8], timestamp: UInt32
    ) async throws {
        guard state == .recording else { return }
        try await recorder.writeAudio(data, timestamp: timestamp)
    }

    /// Record stream metadata.
    ///
    /// No-op if DVR is not in `.recording` state.
    ///
    /// - Parameter metadata: The stream metadata to record.
    /// - Throws: If writing fails.
    public func recordMetadata(_ metadata: StreamMetadata) async throws {
        guard state == .recording else { return }
        try await recorder.writeMetadata(metadata)
    }

    // MARK: - Statistics

    /// Completed segments.
    public var completedSegments: [RecordingSegment] {
        get async {
            await recorder.completedSegments
        }
    }

    /// Total bytes written across all segments.
    public var totalBytesWritten: Int {
        get async {
            await recorder.totalBytesWritten
        }
    }
}
