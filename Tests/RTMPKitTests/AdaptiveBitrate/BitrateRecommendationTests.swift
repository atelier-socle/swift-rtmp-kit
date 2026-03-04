// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("BitrateRecommendation — Value Semantics")
struct BitrateRecommendationTests {

    private func makeSnapshot(
        estimatedBandwidth: Int = 3_000_000,
        roundTripTime: Double? = 0.05,
        rttBaseline: Double? = 0.04,
        dropRate: Double = 0.01,
        pendingBytes: Int = 1024,
        timestamp: Double = 1.0
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            estimatedBandwidth: estimatedBandwidth,
            roundTripTime: roundTripTime,
            rttBaseline: rttBaseline,
            dropRate: dropRate,
            pendingBytes: pendingBytes,
            timestamp: timestamp
        )
    }

    @Test("Struct stores all fields correctly")
    func storesFields() {
        let snapshot = makeSnapshot()
        let recommendation = BitrateRecommendation(
            previousBitrate: 3_000_000,
            recommendedBitrate: 2_250_000,
            reason: .congestionDetected,
            triggerMetrics: snapshot
        )
        #expect(recommendation.previousBitrate == 3_000_000)
        #expect(recommendation.recommendedBitrate == 2_250_000)
        #expect(recommendation.reason == .congestionDetected)
        #expect(recommendation.triggerMetrics == snapshot)
    }

    @Test("Two identical recommendations are equal")
    func equatableIdentical() {
        let snapshot = makeSnapshot()
        let a = BitrateRecommendation(
            previousBitrate: 3_000_000,
            recommendedBitrate: 2_250_000,
            reason: .rttSpike,
            triggerMetrics: snapshot
        )
        let b = BitrateRecommendation(
            previousBitrate: 3_000_000,
            recommendedBitrate: 2_250_000,
            reason: .rttSpike,
            triggerMetrics: snapshot
        )
        #expect(a == b)
    }

    @Test("TriggerMetrics NetworkSnapshot fields are embedded correctly")
    func snapshotFieldsEmbedded() {
        let snapshot = makeSnapshot(
            estimatedBandwidth: 5_000_000,
            roundTripTime: 0.08,
            rttBaseline: 0.04,
            dropRate: 0.02,
            pendingBytes: 2048,
            timestamp: 42.5
        )
        let recommendation = BitrateRecommendation(
            previousBitrate: 4_000_000,
            recommendedBitrate: 3_000_000,
            reason: .dropRateExceeded,
            triggerMetrics: snapshot
        )
        #expect(recommendation.triggerMetrics.estimatedBandwidth == 5_000_000)
        #expect(recommendation.triggerMetrics.roundTripTime == 0.08)
        #expect(recommendation.triggerMetrics.rttBaseline == 0.04)
        #expect(recommendation.triggerMetrics.dropRate == 0.02)
        #expect(recommendation.triggerMetrics.pendingBytes == 2048)
        #expect(recommendation.triggerMetrics.timestamp == 42.5)
    }

    @Test("NetworkSnapshot roundTripTime and rttBaseline can be nil")
    func snapshotNilOptionals() {
        let snapshot = makeSnapshot(roundTripTime: nil, rttBaseline: nil)
        #expect(snapshot.roundTripTime == nil)
        #expect(snapshot.rttBaseline == nil)
    }
}
