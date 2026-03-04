// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AdaptiveBitratePolicy — Configuration Resolution")
struct AdaptiveBitratePolicyTests {

    @Test("Disabled policy returns nil configuration")
    func disabledReturnsNil() {
        let policy = AdaptiveBitratePolicy.disabled
        #expect(policy.configuration == nil)
    }

    @Test("Conservative policy returns conservative configuration")
    func conservativeReturnsConfig() {
        let policy = AdaptiveBitratePolicy.conservative(min: 500_000, max: 6_000_000)
        let config = policy.configuration
        #expect(config != nil)
        #expect(config?.minBitrate == 500_000)
        #expect(config?.maxBitrate == 6_000_000)
        #expect(config?.stepDown == 0.80)
    }

    @Test("Responsive policy returns responsive configuration")
    func responsiveReturnsConfig() {
        let policy = AdaptiveBitratePolicy.responsive(min: 300_000, max: 8_000_000)
        let config = policy.configuration
        #expect(config != nil)
        #expect(config?.minBitrate == 300_000)
        #expect(config?.maxBitrate == 8_000_000)
        #expect(config?.stepDown == 0.75)
    }

    @Test("Aggressive policy returns aggressive configuration")
    func aggressiveReturnsConfig() {
        let policy = AdaptiveBitratePolicy.aggressive(min: 200_000, max: 4_000_000)
        let config = policy.configuration
        #expect(config != nil)
        #expect(config?.minBitrate == 200_000)
        #expect(config?.maxBitrate == 4_000_000)
        #expect(config?.stepDown == 0.65)
    }

    @Test("Custom policy returns provided configuration unchanged")
    func customReturnsConfig() {
        let customConfig = AdaptiveBitrateConfiguration(
            minBitrate: 100_000,
            maxBitrate: 10_000_000,
            stepDown: 0.70,
            stepUp: 1.20,
            downTriggerThreshold: 0.35,
            upStabilityDuration: 15.0,
            measurementWindow: 4.0,
            dropRateTriggerThreshold: 0.05
        )
        let policy = AdaptiveBitratePolicy.custom(customConfig)
        #expect(policy.configuration == customConfig)
    }

    @Test("Equatable conformance works correctly")
    func equatable() {
        #expect(AdaptiveBitratePolicy.disabled == .disabled)
        #expect(
            AdaptiveBitratePolicy.conservative(min: 500_000, max: 6_000_000)
                == .conservative(min: 500_000, max: 6_000_000)
        )
        #expect(
            AdaptiveBitratePolicy.conservative(min: 500_000, max: 6_000_000)
                != .responsive(min: 500_000, max: 6_000_000)
        )
    }
}
