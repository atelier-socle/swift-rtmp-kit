// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPServerSecurityPolicy")
struct RTMPServerSecurityPolicyTests {

    @Test(".open has no access control or rate limiter")
    func openPolicy() {
        let policy = RTMPServerSecurityPolicy.open
        #expect(policy.accessControl == nil)
        #expect(policy.rateLimiter == nil)
        #expect(policy.maxStreamDuration == nil)
        #expect(policy.maxIngestBitrate == nil)
    }

    @Test(".standard has a non-nil rate limiter")
    func standardHasRateLimiter() {
        let policy = RTMPServerSecurityPolicy.standard
        #expect(policy.rateLimiter != nil)
    }

    @Test(".strict has shorter per-IP limit than .standard")
    func strictVsStandard() async {
        let standard = RTMPServerSecurityPolicy.standard
        let strict = RTMPServerSecurityPolicy.strict
        let standardLimit =
            await standard.rateLimiter?.maxConnectionsPerIPPerMinute ?? 0
        let strictLimit =
            await strict.rateLimiter?.maxConnectionsPerIPPerMinute ?? 0
        #expect(strictLimit < standardLimit)
    }

    @Test("maxStreamDuration is nil in .open")
    func openNoDuration() {
        let policy = RTMPServerSecurityPolicy.open
        #expect(policy.maxStreamDuration == nil)
    }

    @Test("policy stored in RTMPServerConfiguration")
    func policyInConfig() {
        let config = RTMPServerConfiguration(
            securityPolicy: .strict
        )
        #expect(config.securityPolicy.maxStreamDuration == 28800)
    }

    @Test("configuration with strict policy has rate limiter")
    func configStrictHasRateLimiter() {
        let config = RTMPServerConfiguration(
            securityPolicy: .strict
        )
        #expect(config.securityPolicy.rateLimiter != nil)
    }
}
