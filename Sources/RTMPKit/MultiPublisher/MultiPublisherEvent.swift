// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// An event emitted by a ``MultiPublisher``, scoped to a specific destination.
///
/// Provides structured visibility into multi-destination streaming:
/// state changes, per-destination RTMP events, aggregated statistics,
/// and failure threshold notifications.
public enum MultiPublisherEvent: Sendable {

    /// A destination changed its connection state.
    case stateChanged(destinationID: String, state: DestinationState)

    /// A destination emitted an RTMP event.
    case destinationEvent(destinationID: String, event: RTMPEvent)

    /// Aggregated statistics were updated (fired after every sendAudio/sendVideo batch).
    case statisticsUpdated(MultiPublisherStatistics)

    /// The failure threshold was reached and all destinations are being stopped.
    ///
    /// Only emitted when ``MultiPublisherFailurePolicy/stopAllOnFailure(count:)``
    /// policy is active.
    case failureThresholdReached(failedCount: Int)
}
