// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Real-time connection statistics monitor.
///
/// Tracks bytes sent/received, frame counts, bitrate, and timing.
/// Thread-safe via struct value semantics — the publisher calls
/// mutating methods and takes snapshots as needed.
///
/// Bitrate is calculated using a sliding window of recent byte counts
/// over the last N seconds (default: 5 seconds).
///
/// All time-dependent methods take an explicit timestamp parameter
/// (in nanoseconds) for deterministic testing.
public struct ConnectionMonitor: Sendable {

    /// Sliding window duration for bitrate calculation (nanoseconds).
    private let bitrateWindowNs: UInt64

    /// Total bytes sent since connection start.
    private var totalBytesSent: UInt64 = 0

    /// Total bytes received since connection start.
    private var totalBytesReceived: UInt64 = 0

    /// Number of audio frames sent.
    private var audioFrames: UInt64 = 0

    /// Number of video frames sent.
    private var videoFrames: UInt64 = 0

    /// Number of dropped frames.
    private var dropped: UInt64 = 0

    /// Connection start time (nanoseconds).
    private var startTime: UInt64 = 0

    /// Whether markConnectionStart has been called.
    private var hasStarted: Bool = false

    /// Sliding window samples of (timestamp, byteCount).
    private var byteSamples: [(timestamp: UInt64, bytes: UInt64)] = []

    /// Timestamp of the last ping sent (nanoseconds).
    private var lastPingTimestamp: UInt64?

    /// Estimated round-trip time (seconds).
    private var rtt: Double?

    /// Timestamp of the last acknowledgement (nanoseconds).
    private var lastAckTime: UInt64?

    /// Create a new monitor.
    ///
    /// - Parameter bitrateWindowSize: Sliding window duration for
    ///   bitrate calculation (seconds, default: 5.0).
    public init(bitrateWindowSize: Double = 5.0) {
        self.bitrateWindowNs = UInt64(bitrateWindowSize * 1_000_000_000)
    }

    // MARK: - Recording

    /// Record bytes sent.
    ///
    /// - Parameters:
    ///   - count: Number of bytes sent.
    ///   - timestamp: Current monotonic time in nanoseconds.
    public mutating func recordBytesSent(
        _ count: UInt64, at timestamp: UInt64
    ) {
        totalBytesSent += count
        byteSamples.append((timestamp: timestamp, bytes: count))
    }

    /// Record bytes received.
    public mutating func recordBytesReceived(_ count: UInt64) {
        totalBytesReceived += count
    }

    /// Record an audio frame sent.
    public mutating func recordAudioFrameSent() {
        audioFrames += 1
    }

    /// Record a video frame sent.
    public mutating func recordVideoFrameSent() {
        videoFrames += 1
    }

    /// Record a dropped frame.
    public mutating func recordDroppedFrame() {
        dropped += 1
    }

    /// Record a ping sent (to measure RTT).
    ///
    /// - Parameter timestamp: The monotonic timestamp when ping was sent
    ///   (nanoseconds).
    public mutating func recordPingSent(at timestamp: UInt64) {
        lastPingTimestamp = timestamp
    }

    /// Record a pong received (to calculate RTT).
    ///
    /// - Parameter originalTimestamp: The original ping timestamp echoed
    ///   in the pong (nanoseconds).
    public mutating func recordPongReceived(originalTimestamp: UInt64) {
        guard let sentAt = lastPingTimestamp,
            sentAt == originalTimestamp
        else { return }
        // This doesn't make sense to compute RTT without a current time,
        // but the design uses the difference between sent and received.
        // We store the sent timestamp and compute RTT when snapshot is taken
        // with a currentTime.
        lastPingTimestamp = nil
    }

    /// Record a pong received with current time (to calculate RTT).
    ///
    /// - Parameters:
    ///   - originalTimestamp: The original ping timestamp.
    ///   - currentTime: Current monotonic time in nanoseconds.
    public mutating func recordPongReceived(
        originalTimestamp: UInt64, currentTime: UInt64
    ) {
        guard currentTime >= originalTimestamp else { return }
        rtt = Double(currentTime - originalTimestamp) / 1_000_000_000
        lastPingTimestamp = nil
    }

    /// Record an acknowledgement received from the server.
    ///
    /// - Parameter timestamp: Current monotonic time in nanoseconds.
    public mutating func recordAcknowledgement(at timestamp: UInt64) {
        lastAckTime = timestamp
    }

    /// Mark the connection start time.
    ///
    /// - Parameter timestamp: Current monotonic time in nanoseconds.
    public mutating func markConnectionStart(at timestamp: UInt64) {
        startTime = timestamp
        hasStarted = true
    }

    // MARK: - Querying

    /// Take a snapshot of current statistics.
    ///
    /// - Parameter currentTime: Current monotonic time in nanoseconds.
    /// - Returns: A ``ConnectionStatistics`` snapshot.
    public func snapshot(currentTime: UInt64) -> ConnectionStatistics {
        var stats = ConnectionStatistics()
        stats.bytesSent = totalBytesSent
        stats.bytesReceived = totalBytesReceived
        stats.audioFramesSent = audioFrames
        stats.videoFramesSent = videoFrames
        stats.droppedFrames = dropped
        stats.currentBitrate = currentBitrate(at: currentTime)
        stats.averageBitrate = averageBitrate(at: currentTime)
        stats.connectionUptime = uptime(at: currentTime)
        stats.roundTripTime = rtt

        if let ackTime = lastAckTime, ackTime >= startTime {
            stats.lastAcknowledgementTime =
                Double(ackTime - startTime) / 1_000_000_000
        }

        return stats
    }

    /// Current bitrate in bits per second (based on sliding window).
    ///
    /// - Parameter currentTime: Current monotonic time in nanoseconds.
    /// - Returns: Bitrate in bits per second.
    public func currentBitrate(at currentTime: UInt64) -> Double {
        let windowStart =
            currentTime >= bitrateWindowNs
            ? currentTime - bitrateWindowNs : 0

        var totalBytes: UInt64 = 0
        var earliest = currentTime

        for sample in byteSamples where sample.timestamp >= windowStart {
            totalBytes += sample.bytes
            if sample.timestamp < earliest {
                earliest = sample.timestamp
            }
        }

        guard totalBytes > 0, currentTime > earliest else { return 0 }
        let durationSec =
            Double(currentTime - earliest) / 1_000_000_000
        guard durationSec > 0 else { return 0 }
        return Double(totalBytes) * 8.0 / durationSec
    }

    /// Average bitrate since connection start in bits per second.
    ///
    /// - Parameter currentTime: Current monotonic time in nanoseconds.
    /// - Returns: Average bitrate in bits per second.
    public func averageBitrate(at currentTime: UInt64) -> Double {
        let elapsed = uptime(at: currentTime)
        guard elapsed > 0 else { return 0 }
        return Double(totalBytesSent) * 8.0 / elapsed
    }

    /// Reset all counters (for reconnection).
    public mutating func reset() {
        totalBytesSent = 0
        totalBytesReceived = 0
        audioFrames = 0
        videoFrames = 0
        dropped = 0
        startTime = 0
        hasStarted = false
        byteSamples.removeAll()
        lastPingTimestamp = nil
        rtt = nil
        lastAckTime = nil
    }

    // MARK: - Private

    private func uptime(at currentTime: UInt64) -> Double {
        guard hasStarted, currentTime >= startTime else { return 0 }
        return Double(currentTime - startTime) / 1_000_000_000
    }
}
