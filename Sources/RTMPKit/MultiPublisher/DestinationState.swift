// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// State of a single publishing destination within a ``MultiPublisher``.
///
/// Tracks the lifecycle from initial idle through connection, streaming,
/// reconnection attempts, and terminal states (stopped or failed).
public enum DestinationState: Sendable {

    /// Destination has been added but not yet started.
    case idle

    /// Currently connecting or performing handshake.
    case connecting

    /// Handshake complete, stream published, sending A/V.
    case streaming

    /// Connection lost, waiting before next reconnect attempt.
    case reconnecting(attempt: Int)

    /// Permanently stopped — either by caller or after exhausting reconnect policy.
    case stopped

    /// Connection failed with a terminal error (reconnect policy exhausted or disabled).
    case failed(Error)

    /// Whether this destination is actively connected or attempting to connect.
    ///
    /// Returns `true` for ``connecting``, ``streaming``, and ``reconnecting(attempt:)``.
    public var isActive: Bool {
        switch self {
        case .connecting, .streaming, .reconnecting:
            return true
        case .idle, .stopped, .failed:
            return false
        }
    }
}

// MARK: - Equatable

extension DestinationState: Equatable {
    public static func == (lhs: DestinationState, rhs: DestinationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
            (.connecting, .connecting),
            (.streaming, .streaming),
            (.stopped, .stopped),
            (.failed, .failed):
            return true
        case let (.reconnecting(a), .reconnecting(b)):
            return a == b
        default:
            return false
        }
    }
}
