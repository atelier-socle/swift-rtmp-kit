// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AdaptiveBitrateConfiguration — Presets and Validation")
struct AdaptiveBitrateConfigurationTests {

    @Test("Conservative preset has correct values")
    func conservativePresetValues() {
        let config = AdaptiveBitrateConfiguration.conservative(min: 300_000, max: 6_000_000)
        #expect(config.minBitrate == 300_000)
        #expect(config.maxBitrate == 6_000_000)
        #expect(config.stepDown == 0.80)
        #expect(config.stepUp == 1.05)
        #expect(config.downTriggerThreshold == 0.40)
        #expect(config.upStabilityDuration == 20.0)
        #expect(config.measurementWindow == 5.0)
        #expect(config.dropRateTriggerThreshold == 0.03)
    }

    @Test("Responsive preset has correct values")
    func responsivePresetValues() {
        let config = AdaptiveBitrateConfiguration.responsive(min: 500_000, max: 8_000_000)
        #expect(config.minBitrate == 500_000)
        #expect(config.maxBitrate == 8_000_000)
        #expect(config.stepDown == 0.75)
        #expect(config.stepUp == 1.10)
        #expect(config.downTriggerThreshold == 0.25)
        #expect(config.upStabilityDuration == 8.0)
        #expect(config.measurementWindow == 3.0)
        #expect(config.dropRateTriggerThreshold == 0.02)
    }

    @Test("Aggressive preset has correct values")
    func aggressivePresetValues() {
        let config = AdaptiveBitrateConfiguration.aggressive(min: 200_000, max: 4_000_000)
        #expect(config.minBitrate == 200_000)
        #expect(config.maxBitrate == 4_000_000)
        #expect(config.stepDown == 0.65)
        #expect(config.stepUp == 1.15)
        #expect(config.downTriggerThreshold == 0.15)
        #expect(config.upStabilityDuration == 4.0)
        #expect(config.measurementWindow == 2.0)
        #expect(config.dropRateTriggerThreshold == 0.01)
    }

    @Test("All presets produce valid configurations")
    func allPresetsValid() {
        let presets = [
            AdaptiveBitrateConfiguration.conservative(min: 300_000, max: 6_000_000),
            AdaptiveBitrateConfiguration.responsive(min: 300_000, max: 6_000_000),
            AdaptiveBitrateConfiguration.aggressive(min: 300_000, max: 6_000_000)
        ]
        for config in presets {
            #expect(config.stepDown < 1.0)
            #expect(config.stepUp > 1.0)
            #expect(config.minBitrate > 0)
            #expect(config.maxBitrate > 0)
            #expect(config.measurementWindow > 0)
            #expect(config.upStabilityDuration > 0)
        }
    }

    @Test("MinBitrate is strictly less than maxBitrate for all presets")
    func minLessThanMax() {
        let presets = [
            AdaptiveBitrateConfiguration.conservative(min: 300_000, max: 6_000_000),
            AdaptiveBitrateConfiguration.responsive(min: 300_000, max: 6_000_000),
            AdaptiveBitrateConfiguration.aggressive(min: 300_000, max: 6_000_000)
        ]
        for config in presets {
            #expect(config.minBitrate < config.maxBitrate)
        }
    }

    @Test("Custom init stores all provided values")
    func customInitStoresValues() {
        let config = AdaptiveBitrateConfiguration(
            minBitrate: 100_000,
            maxBitrate: 10_000_000,
            stepDown: 0.70,
            stepUp: 1.20,
            downTriggerThreshold: 0.35,
            upStabilityDuration: 15.0,
            measurementWindow: 4.0,
            dropRateTriggerThreshold: 0.05
        )
        #expect(config.minBitrate == 100_000)
        #expect(config.maxBitrate == 10_000_000)
        #expect(config.stepDown == 0.70)
        #expect(config.stepUp == 1.20)
        #expect(config.downTriggerThreshold == 0.35)
        #expect(config.upStabilityDuration == 15.0)
        #expect(config.measurementWindow == 4.0)
        #expect(config.dropRateTriggerThreshold == 0.05)
    }

    @Test("Two identical configurations are equal")
    func equatableIdentical() {
        let a = AdaptiveBitrateConfiguration.responsive(min: 500_000, max: 6_000_000)
        let b = AdaptiveBitrateConfiguration.responsive(min: 500_000, max: 6_000_000)
        #expect(a == b)
    }

    @Test("Two different configurations are not equal")
    func equatableDifferent() {
        let a = AdaptiveBitrateConfiguration.conservative(min: 300_000, max: 6_000_000)
        let b = AdaptiveBitrateConfiguration.aggressive(min: 300_000, max: 6_000_000)
        #expect(a != b)
    }
}
