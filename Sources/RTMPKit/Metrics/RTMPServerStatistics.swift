// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A point-in-time snapshot of RTMP server metrics.
///
/// Captures session counts, throughput, and per-session detail
/// for export to monitoring systems.
public struct RTMPServerStatistics: Sendable {

    // MARK: - Sessions

    /// Number of currently active (publishing) sessions.
    public let activeSessionCount: Int

    /// Total sessions connected since server start.
    public let totalSessionsConnected: Int

    /// Total sessions rejected (auth failure, rate limit, IP block).
    public let totalSessionsRejected: Int

    // MARK: - Throughput

    /// Total bytes received across all sessions since server start.
    public let totalBytesReceived: Int

    /// Current ingest bitrate across all sessions (bps, EWMA over 5s).
    public let currentIngestBitrate: Int

    // MARK: - Frames

    /// Total video frames received since server start.
    public let totalVideoFramesReceived: Int

    /// Total audio frames received since server start.
    public let totalAudioFramesReceived: Int

    // MARK: - Streams

    /// Active stream names at this snapshot.
    public let activeStreamNames: [String]

    // MARK: - Per-session metrics

    /// Per-session metrics keyed by session ID string.
    public let sessionMetrics: [String: SessionMetrics]

    // MARK: - Timestamp

    /// Wall-clock time of this snapshot.
    public let timestamp: Double

    /// Creates a server statistics snapshot.
    ///
    /// - Parameters:
    ///   - activeSessionCount: Current active sessions.
    ///   - totalSessionsConnected: Total sessions connected since start.
    ///   - totalSessionsRejected: Total sessions rejected.
    ///   - totalBytesReceived: Total bytes received.
    ///   - currentIngestBitrate: Current ingest bitrate (bps).
    ///   - totalVideoFramesReceived: Total video frames received.
    ///   - totalAudioFramesReceived: Total audio frames received.
    ///   - activeStreamNames: Active stream names.
    ///   - sessionMetrics: Per-session detail.
    ///   - timestamp: Snapshot timestamp.
    public init(
        activeSessionCount: Int,
        totalSessionsConnected: Int,
        totalSessionsRejected: Int,
        totalBytesReceived: Int,
        currentIngestBitrate: Int,
        totalVideoFramesReceived: Int,
        totalAudioFramesReceived: Int,
        activeStreamNames: [String],
        sessionMetrics: [String: SessionMetrics],
        timestamp: Double
    ) {
        self.activeSessionCount = activeSessionCount
        self.totalSessionsConnected = totalSessionsConnected
        self.totalSessionsRejected = totalSessionsRejected
        self.totalBytesReceived = totalBytesReceived
        self.currentIngestBitrate = currentIngestBitrate
        self.totalVideoFramesReceived = totalVideoFramesReceived
        self.totalAudioFramesReceived = totalAudioFramesReceived
        self.activeStreamNames = activeStreamNames
        self.sessionMetrics = sessionMetrics
        self.timestamp = timestamp
    }
}

extension RTMPServerStatistics {

    /// Per-session metrics detail.
    public struct SessionMetrics: Sendable {

        /// Stream name this session is publishing to.
        public let streamName: String?

        /// Remote address of the publisher.
        public let remoteAddress: String

        /// Session uptime in seconds.
        public let uptimeSeconds: Double

        /// Bytes received from this session.
        public let bytesReceived: Int

        /// Video frames received from this session.
        public let videoFramesReceived: Int

        /// Audio frames received from this session.
        public let audioFramesReceived: Int

        /// Current session state as string.
        public let state: String

        /// Creates a session metrics detail.
        ///
        /// - Parameters:
        ///   - streamName: Stream name, or nil.
        ///   - remoteAddress: Remote address.
        ///   - uptimeSeconds: Session uptime.
        ///   - bytesReceived: Bytes received.
        ///   - videoFramesReceived: Video frames received.
        ///   - audioFramesReceived: Audio frames received.
        ///   - state: Session state string.
        public init(
            streamName: String?,
            remoteAddress: String,
            uptimeSeconds: Double,
            bytesReceived: Int,
            videoFramesReceived: Int,
            audioFramesReceived: Int,
            state: String
        ) {
            self.streamName = streamName
            self.remoteAddress = remoteAddress
            self.uptimeSeconds = uptimeSeconds
            self.bytesReceived = bytesReceived
            self.videoFramesReceived = videoFramesReceived
            self.audioFramesReceived = audioFramesReceived
            self.state = state
        }
    }
}
