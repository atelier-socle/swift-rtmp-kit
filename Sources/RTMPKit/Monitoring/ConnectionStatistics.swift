// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Snapshot of connection statistics at a point in time.
///
/// Captures bytes, frames, bitrate, and timing information.
/// Created by ``ConnectionMonitor/snapshot(currentTime:)``.
public struct ConnectionStatistics: Sendable, Equatable {

    /// Total bytes sent since connection start.
    public var bytesSent: UInt64

    /// Total bytes received since connection start.
    public var bytesReceived: UInt64

    /// Number of audio frames sent.
    public var audioFramesSent: UInt64

    /// Number of video frames sent.
    public var videoFramesSent: UInt64

    /// Number of frames dropped (due to backpressure or congestion).
    public var droppedFrames: UInt64

    /// Current bitrate in bits per second (sliding window average).
    public var currentBitrate: Double

    /// Average bitrate since connection start in bits per second.
    public var averageBitrate: Double

    /// Time since connection was established (seconds).
    public var connectionUptime: Double

    /// Timestamp of last acknowledgement from server (seconds since start).
    public var lastAcknowledgementTime: Double?

    /// Estimated round-trip time from ping/pong (seconds).
    public var roundTripTime: Double?

    /// Creates empty statistics (all zeros).
    public init() {
        self.bytesSent = 0
        self.bytesReceived = 0
        self.audioFramesSent = 0
        self.videoFramesSent = 0
        self.droppedFrames = 0
        self.currentBitrate = 0
        self.averageBitrate = 0
        self.connectionUptime = 0
        self.lastAcknowledgementTime = nil
        self.roundTripTime = nil
    }

    /// Total frames sent (audio + video).
    public var totalFramesSent: UInt64 {
        audioFramesSent + videoFramesSent
    }

    /// Frame drop rate as a percentage (0.0–100.0).
    ///
    /// Returns 0 when no frames have been sent or dropped.
    public var dropRate: Double {
        let total = totalFramesSent + droppedFrames
        guard total > 0 else { return 0 }
        return Double(droppedFrames) / Double(total) * 100.0
    }
}
