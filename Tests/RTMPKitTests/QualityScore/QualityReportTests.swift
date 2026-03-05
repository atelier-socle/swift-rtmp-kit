// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("QualityReport")
struct QualityReportTests {

    private func makeScore(
        overall: Double, timestamp: Double
    ) -> ConnectionQualityScore {
        ConnectionQualityScore(
            dimensions: [
                .throughput: overall,
                .latency: overall,
                .frameDropRate: overall,
                .stability: overall,
                .bitrateAchievement: overall
            ],
            overall: overall,
            timestamp: timestamp
        )
    }

    @Test("trend is improving when last > first + 0.05")
    func trendImproving() {
        let samples = [
            makeScore(overall: 0.40, timestamp: 1.0),
            makeScore(overall: 0.50, timestamp: 2.0),
            makeScore(overall: 0.60, timestamp: 3.0)
        ]
        let report = QualityReport.build(samples: samples)
        #expect(report?.trend == .improving)
    }

    @Test("trend is degrading when last < first - 0.05")
    func trendDegrading() {
        let samples = [
            makeScore(overall: 0.80, timestamp: 1.0),
            makeScore(overall: 0.70, timestamp: 2.0),
            makeScore(overall: 0.50, timestamp: 3.0)
        ]
        let report = QualityReport.build(samples: samples)
        #expect(report?.trend == .degrading)
    }

    @Test("trend is stable when change < 0.05")
    func trendStable() {
        let samples = [
            makeScore(overall: 0.70, timestamp: 1.0),
            makeScore(overall: 0.71, timestamp: 2.0),
            makeScore(overall: 0.72, timestamp: 3.0)
        ]
        let report = QualityReport.build(samples: samples)
        #expect(report?.trend == .stable)
    }

    @Test("averageScore.overall is the mean of sample overalls")
    func averageMean() {
        let samples = [
            makeScore(overall: 0.60, timestamp: 1.0),
            makeScore(overall: 0.80, timestamp: 2.0),
            makeScore(overall: 1.00, timestamp: 3.0)
        ]
        let report = QualityReport.build(samples: samples)
        #expect(report != nil)
        let avg = report?.averageScore.overall ?? 0
        #expect(abs(avg - 0.80) < 0.01)
    }

    @Test("minimumScore has the lowest overall of all samples")
    func minimumLowest() {
        let samples = [
            makeScore(overall: 0.60, timestamp: 1.0),
            makeScore(overall: 0.30, timestamp: 2.0),
            makeScore(overall: 0.80, timestamp: 3.0)
        ]
        let report = QualityReport.build(samples: samples)
        #expect(report?.minimumScore.overall == 0.30)
    }

    @Test("maximumScore has the highest overall of all samples")
    func maximumHighest() {
        let samples = [
            makeScore(overall: 0.60, timestamp: 1.0),
            makeScore(overall: 0.30, timestamp: 2.0),
            makeScore(overall: 0.80, timestamp: 3.0)
        ]
        let report = QualityReport.build(samples: samples)
        #expect(report?.maximumScore.overall == 0.80)
    }

    @Test("build returns nil for empty samples")
    func emptyReturnsNil() {
        let report = QualityReport.build(samples: [])
        #expect(report == nil)
    }
}
