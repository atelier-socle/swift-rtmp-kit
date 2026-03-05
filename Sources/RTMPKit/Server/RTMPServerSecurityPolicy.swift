// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A security policy combining all server-side protection mechanisms.
///
/// Aggregates stream key validation, IP access control, rate limiting,
/// and stream duration/bitrate limits into a single configurable object.
///
/// ## Usage
/// ```swift
/// var config = RTMPServerConfiguration.production
/// config.securityPolicy = .strict
/// let server = RTMPServer(configuration: config)
/// ```
public struct RTMPServerSecurityPolicy: Sendable {

    /// Stream key validator.
    public var streamKeyValidator: any StreamKeyValidator

    /// IP access control. nil means allow all IPs.
    public var accessControl: RTMPServerAccessControl?

    /// Connection rate limiter. nil means no limiting.
    public var rateLimiter: RTMPConnectionRateLimiter?

    /// Maximum stream duration in seconds. nil means unlimited.
    public var maxStreamDuration: Double?

    /// Maximum allowed video bitrate in bps (ingest).
    /// Streams exceeding this are rejected. nil means unlimited.
    public var maxIngestBitrate: Int?

    /// Creates a security policy.
    ///
    /// - Parameters:
    ///   - streamKeyValidator: Validator for stream keys.
    ///   - accessControl: IP access control.
    ///   - rateLimiter: Connection rate limiter.
    ///   - maxStreamDuration: Max stream duration in seconds.
    ///   - maxIngestBitrate: Max ingest bitrate in bps.
    public init(
        streamKeyValidator: any StreamKeyValidator = AllowAllStreamKeyValidator(),
        accessControl: RTMPServerAccessControl? = nil,
        rateLimiter: RTMPConnectionRateLimiter? = nil,
        maxStreamDuration: Double? = nil,
        maxIngestBitrate: Int? = nil
    ) {
        self.streamKeyValidator = streamKeyValidator
        self.accessControl = accessControl
        self.rateLimiter = rateLimiter
        self.maxStreamDuration = maxStreamDuration
        self.maxIngestBitrate = maxIngestBitrate
    }
}

extension RTMPServerSecurityPolicy {

    /// Open policy — no restrictions.
    public static let open = RTMPServerSecurityPolicy()

    /// Standard policy — allow-all validator, 10 conn/IP/min rate limit.
    public static let standard = RTMPServerSecurityPolicy(
        rateLimiter: RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 10,
            maxTotalConnectionsPerMinute: 60
        )
    )

    /// Strict policy — 5 conn/IP/min, auto-ban, max 8 hours stream duration.
    public static let strict = RTMPServerSecurityPolicy(
        rateLimiter: RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 5,
            maxTotalConnectionsPerMinute: 30,
            autoBanOnExcess: true,
            autoBanDuration: 600
        ),
        maxStreamDuration: 28800
    )
}
