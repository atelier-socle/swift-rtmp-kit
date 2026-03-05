// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ConnectionQualityScore")
struct ConnectionQualityScoreTests {

    private func allDimensions(value: Double) -> [QualityDimension: Double] {
        var dims: [QualityDimension: Double] = [:]
        for dim in QualityDimension.allCases {
            dims[dim] = value
        }
        return dims
    }

    @Test("score(for:) returns correct value for each dimension")
    func scoreForDimension() {
        let dims: [QualityDimension: Double] = [
            .throughput: 0.9,
            .latency: 0.8,
            .frameDropRate: 0.7,
            .stability: 0.6,
            .bitrateAchievement: 0.5
        ]
        let score = ConnectionQualityScore(dimensions: dims, timestamp: 1.0)
        #expect(score.score(for: .throughput) == 0.9)
        #expect(score.score(for: .latency) == 0.8)
        #expect(score.score(for: .frameDropRate) == 0.7)
        #expect(score.score(for: .stability) == 0.6)
        #expect(score.score(for: .bitrateAchievement) == 0.5)
    }

    @Test("score(for:) returns nil for missing dimension")
    func scoreForMissing() {
        let dims: [QualityDimension: Double] = [.throughput: 0.9]
        let score = ConnectionQualityScore(dimensions: dims, timestamp: 1.0)
        #expect(score.score(for: .latency) == nil)
    }

    @Test("overall is the weighted sum of all dimensions")
    func overallWeightedSum() {
        let dims: [QualityDimension: Double] = [
            .throughput: 1.0,
            .latency: 1.0,
            .frameDropRate: 1.0,
            .stability: 1.0,
            .bitrateAchievement: 1.0
        ]
        let score = ConnectionQualityScore(dimensions: dims, timestamp: 1.0)
        #expect(abs(score.overall - 1.0) < 0.001)
    }

    @Test("grade for overall 0.90 is excellent")
    func gradeExcellent() {
        let score = ConnectionQualityScore(
            dimensions: allDimensions(value: 0.95),
            timestamp: 1.0
        )
        #expect(score.grade == .excellent)
    }

    @Test("grade for overall 0.75 is good")
    func gradeGood() {
        let dims: [QualityDimension: Double] = [
            .throughput: 0.75,
            .latency: 0.75,
            .frameDropRate: 0.75,
            .stability: 0.75,
            .bitrateAchievement: 0.75
        ]
        let score = ConnectionQualityScore(dimensions: dims, timestamp: 1.0)
        #expect(score.grade == .good)
    }

    @Test("grade for overall 0.55 is fair")
    func gradeFair() {
        let score = ConnectionQualityScore(
            dimensions: allDimensions(value: 0.55),
            timestamp: 1.0
        )
        #expect(score.grade == .fair)
    }

    @Test("grade for overall 0.35 is poor")
    func gradePoor() {
        let score = ConnectionQualityScore(
            dimensions: allDimensions(value: 0.35),
            timestamp: 1.0
        )
        #expect(score.grade == .poor)
    }

    @Test("grade for overall 0.20 is critical")
    func gradeCritical() {
        let score = ConnectionQualityScore(
            dimensions: allDimensions(value: 0.20),
            timestamp: 1.0
        )
        #expect(score.grade == .critical)
    }

    @Test("hasWarning true when any dimension < 0.40")
    func hasWarningTrue() {
        var dims = allDimensions(value: 0.9)
        dims[.latency] = 0.30
        let score = ConnectionQualityScore(dimensions: dims, timestamp: 1.0)
        #expect(score.hasWarning)
    }

    @Test("hasWarning false when all dimensions >= 0.40")
    func hasWarningFalse() {
        let score = ConnectionQualityScore(
            dimensions: allDimensions(value: 0.50),
            timestamp: 1.0
        )
        #expect(!score.hasWarning)
    }

    @Test("weakDimensions contains only dimensions with score < 0.40")
    func weakDimensionsFilters() {
        var dims = allDimensions(value: 0.9)
        dims[.latency] = 0.30
        dims[.stability] = 0.20
        let score = ConnectionQualityScore(dimensions: dims, timestamp: 1.0)
        let weak = Set(score.weakDimensions)
        #expect(weak == [.latency, .stability])
    }

    @Test("Grade Comparable: excellent > good > fair > poor > critical")
    func gradeComparable() {
        #expect(
            ConnectionQualityScore.Grade.excellent
                > ConnectionQualityScore.Grade.good
        )
        #expect(
            ConnectionQualityScore.Grade.good
                > ConnectionQualityScore.Grade.fair
        )
        #expect(
            ConnectionQualityScore.Grade.fair
                > ConnectionQualityScore.Grade.poor
        )
        #expect(
            ConnectionQualityScore.Grade.poor
                > ConnectionQualityScore.Grade.critical
        )
    }
}
