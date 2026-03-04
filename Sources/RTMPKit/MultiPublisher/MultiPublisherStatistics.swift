// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch

/// Aggregated statistics snapshot across all destinations in a ``MultiPublisher``.
///
/// Provides both per-destination breakdowns and totals for monitoring
/// multi-destination streaming health.
public struct MultiPublisherStatistics: Sendable, Equatable {

    /// Statistics snapshot per destination ID.
    public let perDestination: [String: ConnectionStatistics]

    /// Number of destinations currently in ``DestinationState/streaming`` state.
    public let activeCount: Int

    /// Number of destinations in ``DestinationState/failed(_:)`` or ``DestinationState/stopped`` state.
    public let inactiveCount: Int

    /// Total bytes sent across all destinations.
    public let totalBytesSent: Int

    /// Total frames dropped across all destinations.
    public let totalDroppedFrames: Int

    /// Timestamp of this snapshot (continuous time, nanoseconds).
    public let timestamp: Double

    /// Creates a statistics snapshot.
    ///
    /// - Parameters:
    ///   - perDestination: Per-destination statistics.
    ///   - activeCount: Number of streaming destinations.
    ///   - inactiveCount: Number of failed or stopped destinations.
    ///   - totalBytesSent: Total bytes sent across all destinations.
    ///   - totalDroppedFrames: Total frames dropped across all destinations.
    ///   - timestamp: Snapshot timestamp.
    public init(
        perDestination: [String: ConnectionStatistics] = [:],
        activeCount: Int = 0,
        inactiveCount: Int = 0,
        totalBytesSent: Int = 0,
        totalDroppedFrames: Int = 0,
        timestamp: Double = 0
    ) {
        self.perDestination = perDestination
        self.activeCount = activeCount
        self.inactiveCount = inactiveCount
        self.totalBytesSent = totalBytesSent
        self.totalDroppedFrames = totalDroppedFrames
        self.timestamp = timestamp
    }
}
