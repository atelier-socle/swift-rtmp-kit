// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Comprehensive RTMP error hierarchy.
///
/// Covers all failure modes across the RTMP publish lifecycle:
/// connection, handshake, protocol framing, command responses,
/// state management, and URL parsing.
public enum RTMPError: Error, Sendable, Equatable {

    // MARK: - Connection

    /// TCP or TLS connection failed.
    case connectionFailed(String)

    /// Connection attempt timed out.
    case connectionTimeout

    /// Connection was closed by the server or network.
    case connectionClosed

    /// TLS negotiation failed.
    case tlsError(String)

    // MARK: - Handshake

    /// RTMP handshake failed.
    case handshakeFailed(String)

    /// Server returned an unexpected RTMP version byte.
    case versionMismatch(expected: UInt8, received: UInt8)

    // MARK: - Protocol

    /// Received an invalid or unrecognized chunk header.
    case invalidChunkHeader

    /// Received a message with an unsupported type ID.
    case invalidMessageType(UInt8)

    /// Message exceeds the maximum allowed size.
    case messageTooLarge(UInt32)

    // MARK: - Command

    /// Server rejected the RTMP connect command.
    case connectRejected(code: String, description: String)

    /// Creating a new message stream failed.
    case createStreamFailed(String)

    /// Server rejected the publish command.
    case publishFailed(code: String, description: String)

    /// Server sent a response that does not match expectations.
    case unexpectedResponse(String)

    /// A command timed out waiting for a server response.
    case transactionTimeout(transactionID: Int)

    // MARK: - State

    /// Operation not allowed in the current state.
    case invalidState(String)

    /// The transport is not connected.
    case notConnected

    /// Cannot send media — not in publishing state.
    case notPublishing

    /// Already in publishing state.
    case alreadyPublishing

    /// Reconnection attempts exhausted.
    case reconnectExhausted(attempts: Int)

    // MARK: - URL

    /// The RTMP URL could not be parsed.
    case invalidURL(String)
}

extension RTMPError: CustomStringConvertible {

    /// Human-readable error description.
    public var description: String {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .connectionTimeout:
            return "Connection timed out"
        case .connectionClosed:
            return "Connection closed by server"
        case .tlsError(let reason):
            return "TLS error: \(reason)"
        case .handshakeFailed(let reason):
            return "Handshake failed: \(reason)"
        case .versionMismatch(let expected, let received):
            return
                "RTMP version mismatch: expected \(expected), "
                + "got \(received)"
        case .invalidChunkHeader:
            return "Invalid chunk header"
        case .invalidMessageType(let typeID):
            return "Invalid message type: \(typeID)"
        case .messageTooLarge(let size):
            return "Message too large: \(size) bytes"
        case .connectRejected(let code, let desc):
            return
                "Connection rejected: \(code)"
                + (desc.isEmpty ? "" : " — \(desc)")
        case .createStreamFailed(let reason):
            return "Create stream failed: \(reason)"
        case .publishFailed(let code, let desc):
            return
                "Publish rejected: \(code)"
                + (desc.isEmpty ? "" : " — \(desc)")
        case .unexpectedResponse(let detail):
            return "Unexpected server response: \(detail)"
        case .transactionTimeout(let txnID):
            return
                "Command timed out (transaction \(txnID))"
        case .invalidState(let detail):
            return "Invalid state: \(detail)"
        case .notConnected:
            return "Not connected"
        case .notPublishing:
            return "Not publishing"
        case .alreadyPublishing:
            return "Already publishing"
        case .reconnectExhausted(let attempts):
            return
                "Reconnection exhausted after "
                + "\(attempts) attempts"
        case .invalidURL(let url):
            return "Invalid RTMP URL: \(url)"
        }
    }
}
