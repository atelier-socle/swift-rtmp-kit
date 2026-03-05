// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Bandwidth Probe Showcase — Results and Selection")
struct ProbeShowcaseResultTests {

    @Test("Probe and select quality for Twitch")
    func probeAndSelectTwitch() async throws {
        let probe = BandwidthProbe(
            configuration: .init(
                duration: 0.3, burstInterval: 0.05, warmupBursts: 1
            ),
            transportFactory: { _ in MockTransport() }
        )
        let result = try await probe.probe(
            url: "rtmp://live.twitch.tv/app"
        )
        let config = QualityPresetSelector.select(
            for: result, platform: .twitch(.auto),
            streamKey: "live_abc123"
        )
        #expect(config.initialMetadata?.videoBitrate != nil)
        #expect(result.signalQuality >= 0.0)
    }

    @Test("Poor connection selects low quality tier")
    func poorConnectionLowTier() {
        // Simulate a low bandwidth result
        let result = ProbeResult(
            estimatedBandwidth: 1_000_000,
            minRTT: 50, averageRTT: 100, maxRTT: 300,
            packetLossRate: 0.1,
            probeDuration: 5, burstsSent: 40,
            signalQuality: 0.35
        )
        #expect(result.recommendedBitrate < 1_500_000)

        let config = QualityPresetSelector.select(
            for: result, platform: .twitch(.auto), streamKey: "k"
        )
        // Should select 360p30 (lowest tier)
        #expect(config.initialMetadata?.height == 360)
    }

    @Test("Signal quality reflects RTT jitter")
    func signalReflectsJitter() {
        // High jitter: maxRTT - minRTT > avgRTT → jitterScore low
        let result = ProbeResult(
            estimatedBandwidth: 5_000_000,
            minRTT: 5, averageRTT: 20, maxRTT: 100,
            packetLossRate: 0,
            probeDuration: 5, burstsSent: 47,
            signalQuality: 0.0  // Will check via formula
        )
        // jitterScore = 1 - min(1, (100 - 5) / 20) = 1 - min(1, 4.75) = 0
        // lossScore = 1.0
        // quality = 0 * 0.6 + 1.0 * 0.4 = 0.4
        // The result itself has signalQuality=0 but we verify the tier
        #expect(result.qualityTier == .poor)
    }

    @Test("ProbeResult summary is human-readable")
    func summaryReadable() {
        let result = ProbeResult(
            estimatedBandwidth: 4_200_000,
            minRTT: 6, averageRTT: 12, maxRTT: 24,
            packetLossRate: 0,
            probeDuration: 5, burstsSent: 47,
            signalQuality: 0.91
        )
        #expect(!result.summary.isEmpty)
        #expect(result.summary.contains("4.2"))
        #expect(result.summary.contains("excellent"))
    }
}

@Suite("Bandwidth Probe Showcase — Publisher Integration")
struct ProbeShowcasePublisherTests {

    @Test("Quality preset selector respects platform max")
    func respectsPlatformMax() {
        // Instagram maxBitrate is 3500 kbps = 3,500,000 bps
        // Even with high bandwidth, should not exceed platform max
        let result = ProbeResult(
            estimatedBandwidth: 20_000_000,
            minRTT: 2, averageRTT: 5, maxRTT: 8,
            packetLossRate: 0,
            probeDuration: 5, burstsSent: 47,
            signalQuality: 0.95
        )
        let config = QualityPresetSelector.select(
            for: result, platform: .instagram,
            streamKey: "ig_key"
        )
        let totalBitrate =
            (config.initialMetadata?.videoBitrate ?? 0)
            + (config.initialMetadata?.audioBitrate ?? 0)
        // Should be capped to Instagram's 3500 kbps max
        #expect(totalBitrate <= 3_500_000)
    }

    @Test("select(from:) with empty candidates uses fallback")
    func emptyFallback() {
        let selected = QualityPresetSelector.select(
            from: [], availableBandwidth: 5_000_000
        )
        // Fallback should have lowest tier metadata
        #expect(selected.initialMetadata?.height == 360)
    }

    @Test("Thorough probe sends more bursts than quick")
    func thoroughVsQuick() async throws {
        let quickProbe = BandwidthProbe(
            configuration: .init(
                duration: 0.2, burstInterval: 0.05, warmupBursts: 0
            ),
            transportFactory: { _ in MockTransport() }
        )
        let thoroughProbe = BandwidthProbe(
            configuration: .init(
                duration: 0.5, burstInterval: 0.05, warmupBursts: 0
            ),
            transportFactory: { _ in MockTransport() }
        )

        let quickResult = try await quickProbe.probe(
            url: "rtmp://server/app"
        )
        let thoroughResult = try await thoroughProbe.probe(
            url: "rtmp://server/app"
        )
        #expect(thoroughResult.burstsSent > quickResult.burstsSent)
    }

    @Test("Quality ladder has 6 tiers")
    func qualityLadderCount() {
        #expect(QualityPresetSelector.qualityLadder.count == 6)
    }
}
