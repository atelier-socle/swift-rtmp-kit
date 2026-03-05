// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A point-in-time snapshot of RTMP publisher metrics.
///
/// Captures throughput, frame counts, connection state, and quality score
/// for export to monitoring systems (Prometheus, StatsD).
public struct RTMPPublisherStatistics: Sendable {

    // MARK: - Identity

    /// The stream key being published to.
    public let streamKey: String

    /// The RTMP server URL (host + port only, no key).
    public let serverURL: String

    /// Platform name if using a platform preset (e.g. "twitch"). nil otherwise.
    public let platform: String?

    // MARK: - Throughput

    /// Total bytes sent since connect.
    public let totalBytesSent: Int

    /// Current video bitrate in bps (EWMA over last 5s).
    public let currentVideoBitrate: Int

    /// Current audio bitrate in bps (EWMA over last 5s).
    public let currentAudioBitrate: Int

    /// Peak video bitrate observed since connect (bps).
    public let peakVideoBitrate: Int

    // MARK: - Frames

    /// Total video frames sent since connect.
    public let videoFramesSent: Int

    /// Total audio frames sent since connect.
    public let audioFramesSent: Int

    /// Total video frames dropped (encoder/network backpressure).
    public let videoFramesDropped: Int

    /// Frame drop rate (0.0-1.0) over the last 5s.
    public let frameDropRate: Double

    // MARK: - Connection

    /// Total reconnection attempts since initial connect.
    public let reconnectionCount: Int

    /// Stream uptime in seconds.
    public let uptimeSeconds: Double

    /// Current connection state as a string.
    public let connectionState: String

    // MARK: - Quality

    /// Current overall quality score (0.0-1.0). nil if not yet computed.
    public let qualityScore: Double?

    /// Current quality grade. nil if not yet computed.
    public let qualityGrade: String?

    // MARK: - Timestamp

    /// Wall-clock time of this snapshot (continuous clock seconds).
    public let timestamp: Double

    /// Creates a publisher statistics snapshot.
    ///
    /// - Parameters:
    ///   - streamKey: The stream key being published to.
    ///   - serverURL: The RTMP server URL.
    ///   - platform: Platform preset name, if any.
    ///   - totalBytesSent: Total bytes sent.
    ///   - currentVideoBitrate: Current video bitrate (bps).
    ///   - currentAudioBitrate: Current audio bitrate (bps).
    ///   - peakVideoBitrate: Peak video bitrate (bps).
    ///   - videoFramesSent: Total video frames sent.
    ///   - audioFramesSent: Total audio frames sent.
    ///   - videoFramesDropped: Total video frames dropped.
    ///   - frameDropRate: Current frame drop rate (0.0-1.0).
    ///   - reconnectionCount: Total reconnection attempts.
    ///   - uptimeSeconds: Stream uptime in seconds.
    ///   - connectionState: Current state as string.
    ///   - qualityScore: Quality score (0.0-1.0), or nil.
    ///   - qualityGrade: Quality grade string, or nil.
    ///   - timestamp: Snapshot timestamp.
    public init(
        streamKey: String,
        serverURL: String,
        platform: String? = nil,
        totalBytesSent: Int,
        currentVideoBitrate: Int,
        currentAudioBitrate: Int,
        peakVideoBitrate: Int,
        videoFramesSent: Int,
        audioFramesSent: Int,
        videoFramesDropped: Int,
        frameDropRate: Double,
        reconnectionCount: Int,
        uptimeSeconds: Double,
        connectionState: String = "publishing",
        qualityScore: Double? = nil,
        qualityGrade: String? = nil,
        timestamp: Double
    ) {
        self.streamKey = streamKey
        self.serverURL = serverURL
        self.platform = platform
        self.totalBytesSent = totalBytesSent
        self.currentVideoBitrate = currentVideoBitrate
        self.currentAudioBitrate = currentAudioBitrate
        self.peakVideoBitrate = peakVideoBitrate
        self.videoFramesSent = videoFramesSent
        self.audioFramesSent = audioFramesSent
        self.videoFramesDropped = videoFramesDropped
        self.frameDropRate = frameDropRate
        self.reconnectionCount = reconnectionCount
        self.uptimeSeconds = uptimeSeconds
        self.connectionState = connectionState
        self.qualityScore = qualityScore
        self.qualityGrade = qualityGrade
        self.timestamp = timestamp
    }
}
