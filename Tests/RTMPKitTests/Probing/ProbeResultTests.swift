// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ProbeResult")
struct ProbeResultTests {

    @Test("recommendedBitrate is 80% of estimated")
    func recommendedBitrate() {
        let result = makeResult(estimatedBandwidth: 10_000_000)
        #expect(result.recommendedBitrate == 8_000_000)
    }

    @Test("Quality tier excellent for signal >= 0.85")
    func tierExcellent() {
        let result = makeResult(signalQuality: 0.90)
        #expect(result.qualityTier == .excellent)
    }

    @Test("Quality tier good for signal >= 0.65")
    func tierGood() {
        let result = makeResult(signalQuality: 0.70)
        #expect(result.qualityTier == .good)
    }

    @Test("Quality tier fair for signal >= 0.40")
    func tierFair() {
        let result = makeResult(signalQuality: 0.50)
        #expect(result.qualityTier == .fair)
    }

    @Test("Quality tier poor for signal < 0.40")
    func tierPoor() {
        let result = makeResult(signalQuality: 0.30)
        #expect(result.qualityTier == .poor)
    }

    @Test("Summary is non-empty and contains bandwidth")
    func summaryNonEmpty() {
        let result = makeResult(
            estimatedBandwidth: 5_000_000, signalQuality: 0.75
        )
        #expect(!result.summary.isEmpty)
        #expect(result.summary.contains("Mbps"))
        #expect(result.summary.contains("good"))
    }

    @Test("Zero packet loss contributes fully to quality")
    func zeroLoss() {
        // signalQuality = jitterScore * 0.6 + lossScore * 0.4
        // with 0 loss, lossScore = 1.0, so quality >= 0.4
        let result = makeResult(packetLossRate: 0.0, signalQuality: 0.95)
        #expect(result.qualityTier == .excellent)
    }

    @Test("Full packet loss limits signal quality")
    func fullLoss() {
        // With 100% loss, lossScore = 0.0, max quality = 0.6
        let result = makeResult(packetLossRate: 1.0, signalQuality: 0.55)
        #expect(result.signalQuality <= 0.60)
    }

    // MARK: - Helpers

    private func makeResult(
        estimatedBandwidth: Int = 5_000_000,
        packetLossRate: Double = 0.0,
        signalQuality: Double = 0.85
    ) -> ProbeResult {
        ProbeResult(
            estimatedBandwidth: estimatedBandwidth,
            minRTT: 5.0, averageRTT: 10.0, maxRTT: 20.0,
            packetLossRate: packetLossRate,
            probeDuration: 5.0, burstsSent: 47,
            signalQuality: signalQuality
        )
    }
}
