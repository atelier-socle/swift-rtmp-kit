// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("BitrateChangeReason — Description and Equality")
struct BitrateChangeReasonTests {

    @Test("All cases have non-empty descriptions")
    func allCasesHaveNonEmptyDescriptions() {
        let cases: [BitrateChangeReason] = [
            .congestionDetected,
            .bandwidthRecovered,
            .rttSpike,
            .dropRateExceeded,
            .manual
        ]
        for reason in cases {
            #expect(!reason.description.isEmpty)
        }
    }

    @Test("All descriptions are distinct")
    func allDescriptionsAreDistinct() {
        let cases: [BitrateChangeReason] = [
            .congestionDetected,
            .bandwidthRecovered,
            .rttSpike,
            .dropRateExceeded,
            .manual
        ]
        let descriptions = cases.map(\.description)
        #expect(Set(descriptions).count == descriptions.count)
    }

    @Test("Same case equals itself")
    func sameCaseEquality() {
        #expect(BitrateChangeReason.congestionDetected == .congestionDetected)
        #expect(BitrateChangeReason.bandwidthRecovered == .bandwidthRecovered)
        #expect(BitrateChangeReason.rttSpike == .rttSpike)
        #expect(BitrateChangeReason.dropRateExceeded == .dropRateExceeded)
        #expect(BitrateChangeReason.manual == .manual)
    }

    @Test("Different cases are not equal")
    func differentCasesNotEqual() {
        #expect(BitrateChangeReason.congestionDetected != .bandwidthRecovered)
        #expect(BitrateChangeReason.rttSpike != .manual)
        #expect(BitrateChangeReason.dropRateExceeded != .congestionDetected)
    }
}
