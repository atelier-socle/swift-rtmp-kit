// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Suite 1: Access Control

@Suite("Security Showcase — Access Control")
struct SecurityShowcaseAccessControlTests {

    @Test("IP blocklist prevents connection")
    func blocklistPrevents() async {
        let ac = RTMPServerAccessControl()
        await ac.addToBlocklist("192.168.1.100")
        let allowed = await ac.isAllowed("192.168.1.100")
        #expect(!allowed)
    }

    @Test("temporary ban expires")
    func banExpires() async throws {
        let ac = RTMPServerAccessControl()
        await ac.ban("10.0.0.1", duration: 0.001)
        try await Task.sleep(nanoseconds: 5_000_000)  // 5ms
        let allowed = await ac.isAllowed("10.0.0.1")
        #expect(allowed)
    }

    @Test("allowlist overrides blocklist")
    func allowlistWins() async {
        let ac = RTMPServerAccessControl(
            allowlist: ["10.0.0.1"],
            blocklist: ["10.0.0.1"]
        )
        let allowed = await ac.isAllowed("10.0.0.1")
        #expect(allowed)
    }

    @Test("pruneExpiredBans removes expired entries")
    func pruneExpired() async throws {
        let ac = RTMPServerAccessControl()
        await ac.ban("10.0.0.1", duration: 0.001)
        try await Task.sleep(nanoseconds: 5_000_000)
        await ac.pruneExpiredBans()
        let bans = await ac.temporaryBans
        #expect(bans.isEmpty)
    }
}

// MARK: - Suite 2: Rate Limiting

@Suite("Security Showcase — Rate Limiting")
struct SecurityShowcaseRateLimitingTests {

    @Test("rate limiter allows connections under limit")
    func underLimit() async {
        let limiter = RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 5
        )
        for _ in 0..<5 {
            let result = await limiter.checkAndRecord(ip: "1.2.3.4")
            #expect(result == .allowed)
        }
    }

    @Test("rate limiter blocks on per-IP excess")
    func perIPBlock() async {
        let limiter = RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 3,
            autoBanOnExcess: false
        )
        for _ in 0..<3 {
            _ = await limiter.checkAndRecord(ip: "1.2.3.4")
        }
        let result = await limiter.checkAndRecord(ip: "1.2.3.4")
        #expect(
            result == .perIPLimitExceeded(ip: "1.2.3.4", count: 4)
        )
    }

    @Test("different IPs have independent limits")
    func independentLimits() async {
        let limiter = RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 2,
            autoBanOnExcess: false
        )
        _ = await limiter.checkAndRecord(ip: "a")
        _ = await limiter.checkAndRecord(ip: "a")
        _ = await limiter.checkAndRecord(ip: "a")
        let resultB = await limiter.checkAndRecord(ip: "b")
        #expect(resultB == .allowed)
    }

    @Test("standard policy preset has rate limiting")
    func standardPreset() {
        let policy = RTMPServerSecurityPolicy.standard
        #expect(policy.rateLimiter != nil)
    }
}

// MARK: - Suite 3: Full Security Stack

@Suite("Security Showcase — Full Stack")
struct SecurityShowcaseFullStackTests {

    @Test("open policy allows everything")
    func openAllows() async {
        let policy = RTMPServerSecurityPolicy.open
        let valid = await policy.streamKeyValidator.isValid(
            streamKey: "any-key", app: "live"
        )
        #expect(valid)
        #expect(policy.accessControl == nil)
        #expect(policy.rateLimiter == nil)
    }

    @Test("strict policy rejects fast reconnects")
    func strictRejectsFastReconnects() async {
        let policy = RTMPServerSecurityPolicy.strict
        guard let limiter = policy.rateLimiter else {
            Issue.record("strict policy should have a rate limiter")
            return
        }
        for _ in 0..<5 {
            _ = await limiter.checkAndRecord(ip: "10.0.0.1")
        }
        let result = await limiter.checkAndRecord(ip: "10.0.0.1")
        #expect(result != .allowed)
    }

    @Test("stream key validator rejects invalid key")
    func rejectInvalidKey() async {
        let validator = AllowListStreamKeyValidator(
            allowedKeys: ["valid"]
        )
        let invalid = await validator.isValid(
            streamKey: "invalid", app: "live"
        )
        let valid = await validator.isValid(
            streamKey: "valid", app: "live"
        )
        #expect(!invalid)
        #expect(valid)
    }

    @Test("security policy applied to configuration")
    func policyInConfig() {
        let policy = RTMPServerSecurityPolicy(
            streamKeyValidator: AllowListStreamKeyValidator(
                allowedKeys: ["live_abc"]
            ),
            rateLimiter: RTMPConnectionRateLimiter(
                maxConnectionsPerIPPerMinute: 5
            ),
            maxStreamDuration: 3600
        )
        let config = RTMPServerConfiguration(
            securityPolicy: policy
        )
        #expect(config.securityPolicy.maxStreamDuration == 3600)
        #expect(config.securityPolicy.rateLimiter != nil)
    }
}
