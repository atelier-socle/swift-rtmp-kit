// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Publisher connection and streaming states.
///
/// Represents the lifecycle of an RTMP publish session:
/// ``idle`` → ``connecting`` → ``handshaking`` → ``connected``
/// → ``publishing`` → ``disconnected``.
public enum RTMPPublisherState: Sendable, Equatable {

    /// Initial state — no connection.
    case idle

    /// TCP/TLS connection in progress.
    case connecting

    /// RTMP connect command exchange in progress.
    case handshaking

    /// RTMP connect succeeded — ready to create stream and publish.
    case connected

    /// Actively publishing audio/video data.
    case publishing

    /// Attempting to reconnect after a failure.
    case reconnecting(attempt: Int)

    /// Cleanly disconnected.
    case disconnected

    /// An error occurred.
    case failed(RTMPError)
}
