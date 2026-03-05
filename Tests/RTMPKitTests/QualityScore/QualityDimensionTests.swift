// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("QualityDimension")
struct QualityDimensionTests {

    @Test("allCases has 5 elements")
    func allCasesCount() {
        #expect(QualityDimension.allCases.count == 5)
    }

    @Test("all raw values are distinct strings")
    func rawValuesDistinct() {
        let rawValues = QualityDimension.allCases.map(\.rawValue)
        let unique = Set(rawValues)
        #expect(unique.count == rawValues.count)
    }

    @Test("CaseIterable provides all 5 cases")
    func caseIterableProvides() {
        let expected: Set<QualityDimension> = [
            .throughput, .latency, .frameDropRate,
            .stability, .bitrateAchievement
        ]
        #expect(Set(QualityDimension.allCases) == expected)
    }

    @Test("dimensions match expected raw values")
    func rawValuesMatch() {
        #expect(QualityDimension.throughput.rawValue == "throughput")
        #expect(QualityDimension.latency.rawValue == "latency")
        #expect(QualityDimension.frameDropRate.rawValue == "frameDropRate")
        #expect(QualityDimension.stability.rawValue == "stability")
        #expect(
            QualityDimension.bitrateAchievement.rawValue == "bitrateAchievement"
        )
    }

    @Test("each dimension can be used as a dictionary key")
    func dictionaryKey() {
        var dict: [QualityDimension: Double] = [:]
        for dim in QualityDimension.allCases {
            dict[dim] = 0.5
        }
        #expect(dict.count == 5)
    }

    @Test("dimension weights sum to 1.0")
    func weightsSum() {
        let total = QualityDimension.allCases.map(\.weight).reduce(0, +)
        #expect(abs(total - 1.0) < 0.001)
    }
}
