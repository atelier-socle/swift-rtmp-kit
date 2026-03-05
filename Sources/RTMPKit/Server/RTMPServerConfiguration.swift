// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for an RTMPServer instance.
///
/// Controls binding address, port, session limits, and handshake parameters.
public struct RTMPServerConfiguration: Sendable {

    /// Port to listen on. Default: 1935.
    public var port: Int

    /// Host/address to bind to. Default: "0.0.0.0" (all interfaces).
    public var host: String

    /// Maximum number of concurrent publisher sessions. Default: 10.
    public var maxSessions: Int

    /// Handshake timeout in seconds. Default: 10.0.
    public var handshakeTimeout: Double

    /// Whether to require stream key validation via the delegate. Default: false.
    public var requireStreamKeyValidation: Bool

    /// Chunk size for outgoing messages. Default: 4096.
    public var chunkSize: Int

    /// Creates a server configuration.
    ///
    /// - Parameters:
    ///   - port: Port to listen on.
    ///   - host: Host/address to bind to.
    ///   - maxSessions: Maximum concurrent publisher sessions.
    ///   - handshakeTimeout: Handshake timeout in seconds.
    ///   - requireStreamKeyValidation: Whether to validate stream keys via delegate.
    ///   - chunkSize: Chunk size for outgoing messages.
    public init(
        port: Int = 1935,
        host: String = "0.0.0.0",
        maxSessions: Int = 10,
        handshakeTimeout: Double = 10.0,
        requireStreamKeyValidation: Bool = false,
        chunkSize: Int = 4096
    ) {
        self.port = port
        self.host = host
        self.maxSessions = maxSessions
        self.handshakeTimeout = handshakeTimeout
        self.requireStreamKeyValidation = requireStreamKeyValidation
        self.chunkSize = chunkSize
    }
}

extension RTMPServerConfiguration {

    /// Development configuration: localhost, port 1935, 5 sessions.
    public static let localhost = RTMPServerConfiguration(
        host: "127.0.0.1",
        maxSessions: 5
    )

    /// Production configuration: all interfaces, port 1935, 100 sessions.
    public static let production = RTMPServerConfiguration(
        maxSessions: 100
    )
}
