// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("QualityPresetSelector")
struct QualityPresetSelectorTests {

    @Test("8 Mbps selects 1080p60 tier")
    func tier1080p60() {
        let result = makeResult(bandwidth: 10_500_000)
        let config = QualityPresetSelector.select(
            for: result, platform: .twitch(.auto), streamKey: "k"
        )
        #expect(config.initialMetadata?.width == 1920)
        #expect(config.initialMetadata?.height == 1080)
        #expect(config.initialMetadata?.frameRate == 60)
        #expect(config.initialMetadata?.videoBitrate == 8_000_000)
    }

    @Test("6 Mbps selects 1080p30 tier")
    func tier1080p30() {
        let result = makeResult(bandwidth: 7_800_000)
        let config = QualityPresetSelector.select(
            for: result, platform: .twitch(.auto), streamKey: "k"
        )
        #expect(config.initialMetadata?.videoBitrate == 6_000_000)
        #expect(config.initialMetadata?.frameRate == 30)
    }

    @Test("4 Mbps selects 720p60 tier")
    func tier720p60() {
        let result = makeResult(bandwidth: 5_300_000)
        let config = QualityPresetSelector.select(
            for: result, platform: .twitch(.auto), streamKey: "k"
        )
        #expect(config.initialMetadata?.videoBitrate == 4_000_000)
        #expect(config.initialMetadata?.width == 1280)
    }

    @Test("2.5 Mbps selects 720p30 tier")
    func tier720p30() {
        let result = makeResult(bandwidth: 3_300_000)
        let config = QualityPresetSelector.select(
            for: result, platform: .twitch(.auto), streamKey: "k"
        )
        #expect(config.initialMetadata?.videoBitrate == 2_500_000)
    }

    @Test("1.5 Mbps selects 480p30 tier")
    func tier480p30() {
        let result = makeResult(bandwidth: 2_000_000)
        let config = QualityPresetSelector.select(
            for: result, platform: .twitch(.auto), streamKey: "k"
        )
        #expect(config.initialMetadata?.videoBitrate == 1_500_000)
        #expect(config.initialMetadata?.height == 480)
    }

    @Test("500 kbps selects lowest tier (360p30)")
    func tierLowest() {
        let result = makeResult(bandwidth: 625_000)
        let config = QualityPresetSelector.select(
            for: result, platform: .twitch(.auto), streamKey: "k"
        )
        #expect(config.initialMetadata?.videoBitrate == 800_000)
        #expect(config.initialMetadata?.height == 360)
    }

    @Test("select(from:) picks highest that fits")
    func selectFromCandidates() {
        let high = makeConfig(videoBitrate: 8_000_000)
        let mid = makeConfig(videoBitrate: 4_000_000)
        let low = makeConfig(videoBitrate: 1_000_000)

        let selected = QualityPresetSelector.select(
            from: [high, mid, low], availableBandwidth: 5_000_000
        )
        #expect(selected.initialMetadata?.videoBitrate == 4_000_000)
    }

    @Test("select(from:) with all too high picks lowest")
    func selectFromAllTooHigh() {
        let high = makeConfig(videoBitrate: 8_000_000)
        let mid = makeConfig(videoBitrate: 6_000_000)

        let selected = QualityPresetSelector.select(
            from: [high, mid], availableBandwidth: 1_000_000
        )
        #expect(selected.initialMetadata?.videoBitrate == 6_000_000)
    }

    // MARK: - Helpers

    private func makeResult(bandwidth: Int) -> ProbeResult {
        ProbeResult(
            estimatedBandwidth: bandwidth,
            minRTT: 5, averageRTT: 10, maxRTT: 15,
            packetLossRate: 0,
            probeDuration: 5, burstsSent: 47,
            signalQuality: 0.9
        )
    }

    private func makeConfig(videoBitrate: Int) -> RTMPConfiguration {
        var config = RTMPConfiguration(
            url: "rtmp://server/app", streamKey: "key"
        )
        var meta = StreamMetadata()
        meta.videoBitrate = videoBitrate
        meta.audioBitrate = 128_000
        config.initialMetadata = meta
        return config
    }
}
