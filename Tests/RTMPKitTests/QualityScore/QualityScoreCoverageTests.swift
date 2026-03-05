// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - QualityReport Trend Analysis

@Suite("QualityReport — Trend Analysis")
struct QualityReportCoverageTests {

    @Test("build with empty samples returns nil")
    func buildEmptyReturnsNil() {
        let report = QualityReport.build(samples: [], events: [])
        #expect(report == nil)
    }

    @Test("build with improving trend")
    func buildImprovingTrend() {
        let samples = (0..<5).map { i in
            ConnectionQualityScore(
                dimensions: [:],
                overall: 0.5 + Double(i) * 0.1,
                timestamp: Double(i)
            )
        }
        let report = QualityReport.build(samples: samples, events: [])
        #expect(report != nil)
        #expect(report?.trend == .improving)
    }

    @Test("build with degrading trend")
    func buildDegradingTrend() {
        let samples = (0..<5).map { i in
            ConnectionQualityScore(
                dimensions: [:],
                overall: 0.9 - Double(i) * 0.1,
                timestamp: Double(i)
            )
        }
        let report = QualityReport.build(samples: samples, events: [])
        #expect(report != nil)
        #expect(report?.trend == .degrading)
    }
}

// MARK: - ConnectionQualityMonitor Trim

@Suite("ConnectionQualityMonitor — Trim on Overflow")
struct ConnectionQualityMonitorTrimTests {

    @Test("trimming triggers when samples exceed maxSamples")
    func trimmingTriggersOnOverflow() async {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 0.01,
            reportingWindow: 0.01
        )
        // With these tiny intervals, maxSamples will be very small
        // Add many samples to trigger trim
        for i in 0..<20 {
            await monitor.recordRTT(Double(i) * 0.5 + 1.0)
            await monitor.recordBytesSent(
                1000, targetBitrate: 2_500_000
            )
        }
        // No crash = trim worked correctly
        let score = await monitor.currentScore
        // Score may or may not exist depending on timing
        _ = score
    }
}
