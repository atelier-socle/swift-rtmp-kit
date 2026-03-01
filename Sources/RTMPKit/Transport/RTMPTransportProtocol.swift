// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors specific to the RTMP transport layer.
public enum TransportError: Error, Sendable, Equatable {
    /// The transport is not connected.
    case notConnected
    /// The transport is already connected.
    case alreadyConnected
    /// The connection was closed unexpectedly.
    case connectionClosed
    /// The connection timed out.
    case connectionTimeout
    /// TLS handshake failed.
    case tlsFailure(String)
    /// An invalid state transition was attempted.
    case invalidState(String)
}

/// Protocol abstracting RTMP transport for testability.
///
/// Decouples the publisher actor from NIO, allowing mock transports
/// in unit tests without real network connections.
public protocol RTMPTransportProtocol: Sendable {
    /// Connect to an RTMP server.
    ///
    /// - Parameters:
    ///   - host: The server hostname or IP address.
    ///   - port: The server port (typically 1935 for RTMP, 443 for RTMPS).
    ///   - useTLS: Whether to use TLS (RTMPS).
    /// - Throws: ``TransportError`` on connection failure.
    func connect(host: String, port: Int, useTLS: Bool) async throws

    /// Send raw bytes to the server.
    ///
    /// - Parameter bytes: The bytes to send.
    /// - Throws: ``TransportError`` if not connected.
    func send(_ bytes: [UInt8]) async throws

    /// Receive the next complete RTMP message from the server.
    ///
    /// Blocks until a message is available or the connection closes.
    ///
    /// - Returns: The next complete RTMP message.
    /// - Throws: ``TransportError`` on connection close or error.
    func receive() async throws -> RTMPMessage

    /// Close the connection gracefully.
    func close() async throws

    /// Whether the transport is currently connected.
    var isConnected: Bool { get async }
}
