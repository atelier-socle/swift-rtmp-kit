// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("MultiPublisherStatistics")
struct MultiPublisherStatisticsTests {

    @Test("empty statistics has all zeros")
    func emptyStatistics() {
        let stats = MultiPublisherStatistics()
        #expect(stats.perDestination.isEmpty)
        #expect(stats.activeCount == 0)
        #expect(stats.inactiveCount == 0)
        #expect(stats.totalBytesSent == 0)
        #expect(stats.totalDroppedFrames == 0)
    }

    @Test("activeCount and inactiveCount are stored correctly")
    func countValues() {
        let stats = MultiPublisherStatistics(
            activeCount: 3, inactiveCount: 2
        )
        #expect(stats.activeCount == 3)
        #expect(stats.inactiveCount == 2)
    }

    @Test("totalBytesSent sums correctly")
    func totalBytesSent() {
        var s1 = ConnectionStatistics()
        s1.bytesSent = 1000
        var s2 = ConnectionStatistics()
        s2.bytesSent = 2500
        let stats = MultiPublisherStatistics(
            perDestination: ["a": s1, "b": s2],
            totalBytesSent: 3500
        )
        #expect(stats.totalBytesSent == 3500)
    }

    @Test("totalDroppedFrames sums correctly")
    func totalDroppedFrames() {
        let stats = MultiPublisherStatistics(totalDroppedFrames: 42)
        #expect(stats.totalDroppedFrames == 42)
    }

    @Test("timestamp is stored correctly")
    func timestampStored() {
        let stats = MultiPublisherStatistics(timestamp: 123.456)
        #expect(stats.timestamp == 123.456)
    }
}
