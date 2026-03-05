// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPConnectionRateLimiter")
struct RTMPConnectionRateLimiterTests {

    @Test("initial totalConnectionsThisMinute is 0")
    func initialCount() async {
        let limiter = RTMPConnectionRateLimiter()
        let count = await limiter.totalConnectionsThisMinute
        #expect(count == 0)
    }

    @Test("checkAndRecord returns allowed under limit")
    func allowedUnderLimit() async {
        let limiter = RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 5
        )
        let result = await limiter.checkAndRecord(ip: "1.2.3.4")
        #expect(result == .allowed)
    }

    @Test("checkAndRecord returns perIPLimitExceeded after limit")
    func perIPExceeded() async {
        let limiter = RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 3,
            autoBanOnExcess: false
        )
        for _ in 0..<3 {
            _ = await limiter.checkAndRecord(ip: "1.2.3.4")
        }
        let result = await limiter.checkAndRecord(ip: "1.2.3.4")
        #expect(result == .perIPLimitExceeded(ip: "1.2.3.4", count: 4))
    }

    @Test("checkAndRecord returns globalLimitExceeded")
    func globalExceeded() async {
        let limiter = RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 100,
            maxTotalConnectionsPerMinute: 3
        )
        for i in 0..<3 {
            _ = await limiter.checkAndRecord(ip: "ip-\(i)")
        }
        let result = await limiter.checkAndRecord(ip: "ip-new")
        #expect(result == .globalLimitExceeded(count: 4))
    }

    @Test("connectionCount reflects recorded connections")
    func connectionCountTracking() async {
        let limiter = RTMPConnectionRateLimiter()
        _ = await limiter.checkAndRecord(ip: "10.0.0.1")
        _ = await limiter.checkAndRecord(ip: "10.0.0.1")
        let count = await limiter.connectionCount(for: "10.0.0.1")
        #expect(count == 2)
    }

    @Test("resetCounters resets all counts to 0")
    func resetCounters() async {
        let limiter = RTMPConnectionRateLimiter()
        _ = await limiter.checkAndRecord(ip: "10.0.0.1")
        await limiter.resetCounters()
        let count = await limiter.totalConnectionsThisMinute
        #expect(count == 0)
    }

    @Test("distinct IPs get separate counters")
    func distinctIPs() async {
        let limiter = RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 2,
            autoBanOnExcess: false
        )
        _ = await limiter.checkAndRecord(ip: "a")
        _ = await limiter.checkAndRecord(ip: "a")
        let resultA = await limiter.checkAndRecord(ip: "a")
        let resultB = await limiter.checkAndRecord(ip: "b")
        #expect(resultA == .perIPLimitExceeded(ip: "a", count: 3))
        #expect(resultB == .allowed)
    }

    @Test("auto-ban on per-IP excess")
    func autoBan() async {
        let limiter = RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 1,
            autoBanOnExcess: true,
            autoBanDuration: 300
        )
        _ = await limiter.checkAndRecord(ip: "bad")
        _ = await limiter.checkAndRecord(ip: "bad")
        let banned = await limiter.isBanned("bad")
        #expect(banned)
    }
}
