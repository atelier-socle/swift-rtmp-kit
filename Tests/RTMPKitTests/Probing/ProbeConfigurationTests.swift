// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ProbeConfiguration")
struct ProbeConfigurationTests {

    @Test("Default values")
    func defaultValues() {
        let config = ProbeConfiguration()
        #expect(config.duration == 5.0)
        #expect(config.burstSize == 32_768)
        #expect(config.burstInterval == 0.1)
        #expect(config.maxTestBitrate == 20_000_000)
        #expect(config.warmupBursts == 3)
    }

    @Test("Quick preset has 3 second duration")
    func quickPreset() {
        let config = ProbeConfiguration.quick
        #expect(config.duration == 3.0)
        #expect(config.burstSize == 16_384)
        #expect(config.warmupBursts == 2)
    }

    @Test("Standard preset has 5 second duration")
    func standardPreset() {
        let config = ProbeConfiguration.standard
        #expect(config.duration == 5.0)
        #expect(config.burstSize == 32_768)
    }

    @Test("Thorough preset has 10 second duration")
    func thoroughPreset() {
        let config = ProbeConfiguration.thorough
        #expect(config.duration == 10.0)
        #expect(config.burstSize == 65_536)
        #expect(config.warmupBursts == 5)
    }

    @Test("Custom init stores all values")
    func customInit() {
        let config = ProbeConfiguration(
            duration: 7.5,
            burstSize: 4096,
            burstInterval: 0.5,
            maxTestBitrate: 10_000_000,
            warmupBursts: 1
        )
        #expect(config.duration == 7.5)
        #expect(config.burstSize == 4096)
        #expect(config.burstInterval == 0.5)
        #expect(config.maxTestBitrate == 10_000_000)
        #expect(config.warmupBursts == 1)
    }

    @Test("Negative warmupBursts clamped to zero")
    func warmupBurstsClamped() {
        let config = ProbeConfiguration(warmupBursts: -5)
        #expect(config.warmupBursts == 0)
    }
}
