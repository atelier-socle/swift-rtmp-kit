// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch

/// Rate limits incoming RTMP connections per IP and globally.
///
/// Uses a sliding 60-second window to track connection attempts.
/// Can optionally auto-ban IPs that exceed their per-IP limit.
///
/// ## Usage
/// ```swift
/// let limiter = RTMPConnectionRateLimiter(maxConnectionsPerIPPerMinute: 5)
/// let result = await limiter.checkAndRecord(ip: "1.2.3.4")
/// if result != .allowed { /* reject connection */ }
/// ```
public actor RTMPConnectionRateLimiter {

    // MARK: - Configuration

    /// Maximum connections per IP per minute.
    public let maxConnectionsPerIPPerMinute: Int

    /// Maximum total new connections per minute across all IPs.
    public let maxTotalConnectionsPerMinute: Int

    /// Whether to auto-ban IPs that exceed the per-IP rate limit.
    public let autoBanOnExcess: Bool

    /// Duration of auto-ban in seconds.
    public let autoBanDuration: Double

    // MARK: - Result

    /// Result of a rate limit check.
    public enum RateLimitResult: Sendable, Equatable {
        /// Connection is allowed.
        case allowed
        /// Per-IP limit exceeded.
        case perIPLimitExceeded(ip: String, count: Int)
        /// Global limit exceeded.
        case globalLimitExceeded(count: Int)
    }

    // MARK: - State

    private var connectionRecords: [(ip: String, timestamp: Double)] = []
    private var bannedIPs: [String: Double] = [:]

    // MARK: - Lifecycle

    /// Creates a new rate limiter.
    ///
    /// - Parameters:
    ///   - maxConnectionsPerIPPerMinute: Per-IP limit. Default: 10.
    ///   - maxTotalConnectionsPerMinute: Global limit. Default: 60.
    ///   - autoBanOnExcess: Auto-ban on per-IP excess. Default: true.
    ///   - autoBanDuration: Ban duration in seconds. Default: 300.
    public init(
        maxConnectionsPerIPPerMinute: Int = 10,
        maxTotalConnectionsPerMinute: Int = 60,
        autoBanOnExcess: Bool = true,
        autoBanDuration: Double = 300
    ) {
        self.maxConnectionsPerIPPerMinute = maxConnectionsPerIPPerMinute
        self.maxTotalConnectionsPerMinute = maxTotalConnectionsPerMinute
        self.autoBanOnExcess = autoBanOnExcess
        self.autoBanDuration = autoBanDuration
    }

    // MARK: - Rate check

    /// Record a connection attempt and return whether it is allowed.
    ///
    /// Increments counters and checks against limits.
    ///
    /// - Parameter ip: The IP address of the connecting client.
    /// - Returns: The rate limit result.
    public func checkAndRecord(ip: String) -> RateLimitResult {
        let now = currentTime()
        pruneOldRecords(now: now)

        let totalCount = connectionRecords.count + 1
        if totalCount > maxTotalConnectionsPerMinute {
            return .globalLimitExceeded(count: totalCount)
        }

        let ipCount = connectionRecords.filter({ $0.ip == ip }).count + 1
        if ipCount > maxConnectionsPerIPPerMinute {
            if autoBanOnExcess {
                bannedIPs[ip] = now + autoBanDuration
            }
            return .perIPLimitExceeded(ip: ip, count: ipCount)
        }

        connectionRecords.append((ip: ip, timestamp: now))
        return .allowed
    }

    // MARK: - Stats

    /// Current connection count for the given IP in the current window.
    ///
    /// - Parameter ip: The IP address to check.
    /// - Returns: Number of connections from this IP.
    public func connectionCount(for ip: String) -> Int {
        let now = currentTime()
        let windowStart = now - 60.0
        return connectionRecords.filter {
            $0.ip == ip && $0.timestamp >= windowStart
        }.count
    }

    /// Total connection attempts in the current minute window.
    public var totalConnectionsThisMinute: Int {
        let now = currentTime()
        let windowStart = now - 60.0
        return connectionRecords.filter { $0.timestamp >= windowStart }.count
    }

    /// Reset all counters.
    public func resetCounters() {
        connectionRecords.removeAll()
    }

    /// Check if an IP is currently auto-banned.
    ///
    /// - Parameter ip: The IP address to check.
    /// - Returns: `true` if the IP is currently banned.
    public func isBanned(_ ip: String) -> Bool {
        guard let expiry = bannedIPs[ip] else { return false }
        let now = currentTime()
        if expiry > now {
            return true
        }
        bannedIPs.removeValue(forKey: ip)
        return false
    }

    // MARK: - Internal

    private func pruneOldRecords(now: Double) {
        let windowStart = now - 60.0
        connectionRecords.removeAll { $0.timestamp < windowStart }
        bannedIPs = bannedIPs.filter { $0.value > now }
    }

    private func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }
}
