// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Presets

@Suite("ReconnectPolicy — Presets")
struct ReconnectPolicyPresetTests {

    @Test("default preset values")
    func defaultPreset() {
        let policy = ReconnectPolicy.default
        #expect(policy.maxAttempts == 5)
        #expect(policy.initialDelay == 1.0)
        #expect(policy.maxDelay == 30.0)
        #expect(policy.multiplier == 2.0)
        #expect(policy.jitter == 0.1)
    }

    @Test("aggressive preset values")
    func aggressivePreset() {
        let policy = ReconnectPolicy.aggressive
        #expect(policy.maxAttempts == 10)
        #expect(policy.initialDelay == 0.5)
        #expect(policy.maxDelay == 15.0)
        #expect(policy.multiplier == 1.5)
        #expect(policy.jitter == 0.05)
    }

    @Test("conservative preset values")
    func conservativePreset() {
        let policy = ReconnectPolicy.conservative
        #expect(policy.maxAttempts == 3)
        #expect(policy.initialDelay == 2.0)
        #expect(policy.maxDelay == 60.0)
        #expect(policy.multiplier == 3.0)
        #expect(policy.jitter == 0.2)
    }

    @Test("none preset values")
    func nonePreset() {
        let policy = ReconnectPolicy.none
        #expect(policy.maxAttempts == 0)
        #expect(policy.initialDelay == 0)
        #expect(policy.maxDelay == 0)
        #expect(policy.multiplier == 0)
        #expect(policy.jitter == 0)
    }
}

// MARK: - Delay Calculation

@Suite("ReconnectPolicy — Delay Calculation")
struct ReconnectPolicyDelayTests {

    @Test("base delay for attempt 0 equals initialDelay")
    func baseDelayAttempt0() {
        let policy = ReconnectPolicy(
            maxAttempts: 5, initialDelay: 1.0, maxDelay: 30.0,
            multiplier: 2.0, jitter: 0
        )
        #expect(policy.baseDelay(forAttempt: 0) == 1.0)
    }

    @Test("base delay doubles each attempt with multiplier 2")
    func baseDelayDoubles() {
        let policy = ReconnectPolicy(
            maxAttempts: 5, initialDelay: 1.0, maxDelay: 30.0,
            multiplier: 2.0, jitter: 0
        )
        #expect(policy.baseDelay(forAttempt: 0) == 1.0)
        #expect(policy.baseDelay(forAttempt: 1) == 2.0)
        #expect(policy.baseDelay(forAttempt: 2) == 4.0)
        #expect(policy.baseDelay(forAttempt: 3) == 8.0)
        #expect(policy.baseDelay(forAttempt: 4) == 16.0)
    }

    @Test("base delay capped at maxDelay")
    func baseDelayCapped() {
        let policy = ReconnectPolicy(
            maxAttempts: 10, initialDelay: 1.0, maxDelay: 10.0,
            multiplier: 2.0, jitter: 0
        )
        // attempt 4 = 1*2^4 = 16, capped to 10
        #expect(policy.baseDelay(forAttempt: 4) == 10.0)
    }

    @Test("delay returns nil when attempts exhausted")
    func delayNilWhenExhausted() {
        let policy = ReconnectPolicy.default
        #expect(policy.delay(forAttempt: 5) == nil)
        #expect(policy.delay(forAttempt: 10) == nil)
    }

    @Test("delay returns nil for negative attempt")
    func delayNilForNegative() {
        let policy = ReconnectPolicy.default
        #expect(policy.delay(forAttempt: -1) == nil)
    }

    @Test("none policy first delay returns nil")
    func nonePolicyDelayNil() {
        let policy = ReconnectPolicy.none
        #expect(policy.delay(forAttempt: 0) == nil)
    }

    @Test("zero jitter produces deterministic delay")
    func zeroJitterDeterministic() {
        let policy = ReconnectPolicy(
            maxAttempts: 5, initialDelay: 1.0, maxDelay: 30.0,
            multiplier: 2.0, jitter: 0
        )
        let d1 = policy.delay(forAttempt: 0)
        let d2 = policy.delay(forAttempt: 0)
        #expect(d1 == d2)
        #expect(d1 == 1.0)
    }

    @Test("jitter produces delay within expected range")
    func jitterWithinRange() {
        let policy = ReconnectPolicy(
            maxAttempts: 5, initialDelay: 10.0, maxDelay: 100.0,
            multiplier: 1.0, jitter: 0.1
        )
        // Base = 10.0, jitter ±10% → range [9.0, 11.0]
        for _ in 0..<20 {
            if let d = policy.delay(forAttempt: 0) {
                #expect(d >= 9.0)
                #expect(d <= 11.0)
            }
        }
    }

    @Test("multiplier 1.0 produces constant base delay")
    func constantMultiplier() {
        let policy = ReconnectPolicy(
            maxAttempts: 5, initialDelay: 3.0, maxDelay: 100.0,
            multiplier: 1.0, jitter: 0
        )
        #expect(policy.baseDelay(forAttempt: 0) == 3.0)
        #expect(policy.baseDelay(forAttempt: 1) == 3.0)
        #expect(policy.baseDelay(forAttempt: 2) == 3.0)
        #expect(policy.baseDelay(forAttempt: 4) == 3.0)
    }

    @Test("baseDelay returns nil when exhausted")
    func baseDelayNilWhenExhausted() {
        let policy = ReconnectPolicy.default
        #expect(policy.baseDelay(forAttempt: 5) == nil)
    }
}

// MARK: - Edge Cases & Equatable

@Suite("ReconnectPolicy — Edge Cases")
struct ReconnectPolicyEdgeCaseTests {

    @Test("isEnabled is true for default")
    func isEnabledDefault() {
        #expect(ReconnectPolicy.default.isEnabled == true)
    }

    @Test("isEnabled is false for none")
    func isEnabledNone() {
        #expect(ReconnectPolicy.none.isEnabled == false)
    }

    @Test("custom policy with all parameters")
    func customPolicy() {
        let policy = ReconnectPolicy(
            maxAttempts: 7,
            initialDelay: 0.25,
            maxDelay: 45.0,
            multiplier: 2.5,
            jitter: 0.15
        )
        #expect(policy.maxAttempts == 7)
        #expect(policy.initialDelay == 0.25)
        #expect(policy.maxDelay == 45.0)
        #expect(policy.multiplier == 2.5)
        #expect(policy.jitter == 0.15)
    }

    @Test("same presets are equal")
    func samePresetsEqual() {
        #expect(ReconnectPolicy.default == ReconnectPolicy.default)
        #expect(ReconnectPolicy.none == ReconnectPolicy.none)
        #expect(ReconnectPolicy.aggressive == ReconnectPolicy.aggressive)
        #expect(ReconnectPolicy.conservative == ReconnectPolicy.conservative)
    }

    @Test("different presets are not equal")
    func differentPresetsNotEqual() {
        #expect(ReconnectPolicy.default != ReconnectPolicy.aggressive)
        #expect(ReconnectPolicy.default != ReconnectPolicy.none)
        #expect(ReconnectPolicy.conservative != ReconnectPolicy.aggressive)
    }

    @Test("default init values match default preset")
    func defaultInitMatchesPreset() {
        let defaultInit = ReconnectPolicy()
        let preset = ReconnectPolicy.default
        #expect(defaultInit == preset)
    }

    @Test("mutable properties can be modified")
    func mutableProperties() {
        var policy = ReconnectPolicy.default
        policy.maxAttempts = 20
        #expect(policy.maxAttempts == 20)
        #expect(policy != ReconnectPolicy.default)
    }
}
