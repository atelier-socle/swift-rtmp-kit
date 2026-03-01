// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// TLS version specification for RTMPS connections.
public enum TLSVersion: Sendable {
    /// TLS 1.2 (minimum recommended for RTMPS).
    case tlsv12
    /// TLS 1.3 (preferred when available).
    case tlsv13
}

/// Configuration for RTMP transport connections.
///
/// Controls TCP socket options, connect timeout, and TLS settings.
/// Use ``default`` for standard RTMP streaming or ``lowLatency``
/// for latency-sensitive scenarios.
public struct TransportConfiguration: Sendable, Equatable {

    /// TCP connect timeout in seconds.
    public var connectTimeout: Int

    /// Socket receive buffer size in bytes.
    public var receiveBufferSize: Int

    /// Socket send buffer size in bytes.
    public var sendBufferSize: Int

    /// Whether to enable TCP_NODELAY (disable Nagle's algorithm).
    ///
    /// Recommended for real-time streaming to reduce latency.
    public var tcpNoDelay: Bool

    /// Minimum TLS version for RTMPS connections.
    public var tlsMinimumVersion: TLSVersion

    /// Default configuration suitable for RTMP streaming.
    public static let `default` = TransportConfiguration(
        connectTimeout: 15,
        receiveBufferSize: 64 * 1024,
        sendBufferSize: 64 * 1024,
        tcpNoDelay: true,
        tlsMinimumVersion: .tlsv12
    )

    /// Low-latency configuration with smaller buffers.
    public static let lowLatency = TransportConfiguration(
        connectTimeout: 10,
        receiveBufferSize: 32 * 1024,
        sendBufferSize: 32 * 1024,
        tcpNoDelay: true,
        tlsMinimumVersion: .tlsv12
    )

    /// Creates a transport configuration.
    ///
    /// - Parameters:
    ///   - connectTimeout: TCP connect timeout in seconds (default 15).
    ///   - receiveBufferSize: Socket receive buffer size (default 64 KB).
    ///   - sendBufferSize: Socket send buffer size (default 64 KB).
    ///   - tcpNoDelay: Whether to disable Nagle's algorithm (default true).
    ///   - tlsMinimumVersion: Minimum TLS version (default TLS 1.2).
    public init(
        connectTimeout: Int = 15,
        receiveBufferSize: Int = 64 * 1024,
        sendBufferSize: Int = 64 * 1024,
        tcpNoDelay: Bool = true,
        tlsMinimumVersion: TLSVersion = .tlsv12
    ) {
        self.connectTimeout = connectTimeout
        self.receiveBufferSize = receiveBufferSize
        self.sendBufferSize = sendBufferSize
        self.tcpNoDelay = tcpNoDelay
        self.tlsMinimumVersion = tlsMinimumVersion
    }
}
