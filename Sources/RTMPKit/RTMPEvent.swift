// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Events emitted by ``RTMPPublisher`` via its ``RTMPPublisher/events`` stream.
///
/// Consumers can observe state changes, server messages, and errors
/// without polling.
public enum RTMPEvent: Sendable {

    /// Publisher state changed.
    case stateChanged(RTMPPublisherState)

    /// Server sent a status message (onStatus).
    case serverMessage(code: String, description: String)

    /// Acknowledgement received from server.
    case acknowledgementReceived(sequenceNumber: UInt32)

    /// Server sent a ping request (auto-responded by channel handler).
    case pingReceived

    /// An error occurred (may or may not be fatal).
    case error(RTMPError)

    /// Connection statistics update.
    case statisticsUpdate(ConnectionStatistics)
}
