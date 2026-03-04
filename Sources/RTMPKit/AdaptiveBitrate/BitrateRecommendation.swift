// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// An immutable snapshot of network conditions at a specific point in time.
///
/// Captured by the ``NetworkConditionMonitor`` whenever measurements are ingested
/// and attached to each ``BitrateRecommendation`` as context.
public struct NetworkSnapshot: Sendable, Equatable {

    /// Estimated upload bandwidth in bits per second (EWMA over measurement window).
    public let estimatedBandwidth: Int

    /// Current round-trip time in seconds. `nil` if not yet measured.
    public let roundTripTime: Double?

    /// RTT baseline established during stable connection. `nil` until baseline is set.
    public let rttBaseline: Double?

    /// Frame drop rate fraction over the measurement window (0.0 – 1.0).
    public let dropRate: Double

    /// Number of unacknowledged bytes in the send buffer at measurement time.
    public let pendingBytes: Int

    /// Timestamp of this snapshot (continuous time, seconds since process start).
    public let timestamp: Double

    /// Creates a network snapshot with all fields specified.
    ///
    /// - Parameters:
    ///   - estimatedBandwidth: Estimated upload bandwidth in bits per second.
    ///   - roundTripTime: Current RTT in seconds, or `nil` if not yet measured.
    ///   - rttBaseline: Baseline RTT in seconds, or `nil` until established.
    ///   - dropRate: Frame drop rate fraction (0.0 – 1.0).
    ///   - pendingBytes: Unacknowledged bytes in the send buffer.
    ///   - timestamp: Continuous time in seconds since process start.
    public init(
        estimatedBandwidth: Int,
        roundTripTime: Double?,
        rttBaseline: Double?,
        dropRate: Double,
        pendingBytes: Int,
        timestamp: Double
    ) {
        self.estimatedBandwidth = estimatedBandwidth
        self.roundTripTime = roundTripTime
        self.rttBaseline = rttBaseline
        self.dropRate = dropRate
        self.pendingBytes = pendingBytes
        self.timestamp = timestamp
    }
}

/// An immutable value representing a single bitrate change recommendation
/// emitted by the ``NetworkConditionMonitor``.
public struct BitrateRecommendation: Sendable, Equatable {

    /// The bitrate that was in effect before this recommendation.
    public let previousBitrate: Int

    /// The newly recommended bitrate in bits per second.
    public let recommendedBitrate: Int

    /// The reason that triggered this change.
    public let reason: BitrateChangeReason

    /// The network metrics snapshot that triggered this recommendation.
    public let triggerMetrics: NetworkSnapshot

    /// Creates a bitrate recommendation.
    ///
    /// - Parameters:
    ///   - previousBitrate: The bitrate in effect before this recommendation.
    ///   - recommendedBitrate: The newly recommended bitrate in bits per second.
    ///   - reason: The reason that triggered this change.
    ///   - triggerMetrics: The network snapshot at the time of the recommendation.
    public init(
        previousBitrate: Int,
        recommendedBitrate: Int,
        reason: BitrateChangeReason,
        triggerMetrics: NetworkSnapshot
    ) {
        self.previousBitrate = previousBitrate
        self.recommendedBitrate = recommendedBitrate
        self.reason = reason
        self.triggerMetrics = triggerMetrics
    }
}
