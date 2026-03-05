// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch

/// IP-level access control for the RTMP server.
///
/// Manages allowlists, blocklists, and temporary bans. The access check
/// follows a priority order: allowlist (override) → blocklist → ban → allow.
///
/// ## Usage
/// ```swift
/// let ac = RTMPServerAccessControl(blocklist: ["10.0.0.1"])
/// let allowed = await ac.isAllowed("10.0.0.1")  // false
/// ```
public actor RTMPServerAccessControl {

    // MARK: - Configuration

    /// IPs on the allowlist are always permitted (overrides blocklist).
    /// Empty means no allowlist filtering (all IPs permitted by default).
    public private(set) var allowlist: Set<String>

    /// IPs on the blocklist are always rejected.
    public private(set) var blocklist: Set<String>

    /// Temporarily banned IPs (ip → expiry time as uptime nanoseconds).
    public private(set) var temporaryBans: [String: Double]

    // MARK: - Lifecycle

    /// Creates a new access control instance.
    ///
    /// - Parameters:
    ///   - allowlist: IPs always allowed (overrides blocklist).
    ///   - blocklist: IPs always denied.
    public init(
        allowlist: Set<String> = [],
        blocklist: Set<String> = []
    ) {
        self.allowlist = allowlist
        self.blocklist = blocklist
        self.temporaryBans = [:]
    }

    // MARK: - Allowlist management

    /// Add an IP to the allowlist.
    ///
    /// - Parameter ip: The IP address to allow.
    public func addToAllowlist(_ ip: String) {
        allowlist.insert(ip)
    }

    /// Remove an IP from the allowlist.
    ///
    /// - Parameter ip: The IP address to remove.
    public func removeFromAllowlist(_ ip: String) {
        allowlist.remove(ip)
    }

    // MARK: - Blocklist management

    /// Add an IP to the blocklist.
    ///
    /// - Parameter ip: The IP address to block.
    public func addToBlocklist(_ ip: String) {
        blocklist.insert(ip)
    }

    /// Remove an IP from the blocklist.
    ///
    /// - Parameter ip: The IP address to unblock.
    public func removeFromBlocklist(_ ip: String) {
        blocklist.remove(ip)
    }

    // MARK: - Ban management

    /// Temporarily ban an IP for the given duration.
    ///
    /// - Parameters:
    ///   - ip: The IP address to ban.
    ///   - duration: Ban duration in seconds.
    public func ban(_ ip: String, duration: Double) {
        let now = currentTime()
        temporaryBans[ip] = now + duration
    }

    /// Lift a temporary ban immediately.
    ///
    /// - Parameter ip: The IP address to unban.
    public func unban(_ ip: String) {
        temporaryBans.removeValue(forKey: ip)
    }

    /// Remove all expired bans.
    public func pruneExpiredBans() {
        let now = currentTime()
        temporaryBans = temporaryBans.filter { $0.value > now }
    }

    // MARK: - Access check

    /// Returns true if the given IP is allowed to connect.
    ///
    /// Logic:
    /// 1. If allowlist is non-empty and IP is in allowlist → allow
    /// 2. If allowlist is non-empty and IP is NOT in allowlist → deny
    /// 3. If IP is in blocklist → deny
    /// 4. If IP has an active temporary ban → deny
    /// 5. Otherwise → allow
    ///
    /// - Parameter ip: The IP address to check.
    /// - Returns: `true` if the IP is allowed to connect.
    public func isAllowed(_ ip: String) -> Bool {
        pruneExpiredBans()

        if !allowlist.isEmpty {
            return allowlist.contains(ip)
        }

        if blocklist.contains(ip) {
            return false
        }

        if let expiry = temporaryBans[ip] {
            let now = currentTime()
            if expiry > now {
                return false
            }
            temporaryBans.removeValue(forKey: ip)
        }

        return true
    }

    // MARK: - Internal

    private func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }
}
