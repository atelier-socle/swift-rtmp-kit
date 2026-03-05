// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Policy governing ``MultiPublisher`` behaviour when destinations fail.
///
/// Controls whether failures in individual destinations affect the
/// overall multi-destination streaming session.
public enum MultiPublisherFailurePolicy: Sendable, Equatable {

    /// Continue streaming to remaining destinations regardless of failures (default).
    case continueOnFailure

    /// Stop all destinations once `count` or more have entered
    /// ``DestinationState/failed(_:)`` state.
    case stopAllOnFailure(count: Int)
}
