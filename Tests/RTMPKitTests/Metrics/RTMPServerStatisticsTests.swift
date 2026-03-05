// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPServerStatistics")
struct RTMPServerStatisticsTests {

    private func sampleStats(
        sessionMetrics: [String: RTMPServerStatistics.SessionMetrics] = [:]
    ) -> RTMPServerStatistics {
        RTMPServerStatistics(
            activeSessionCount: sessionMetrics.count,
            totalSessionsConnected: 47,
            totalSessionsRejected: 2,
            totalBytesReceived: 9_876_543,
            currentIngestBitrate: 12_600_000,
            totalVideoFramesReceived: 54_000,
            totalAudioFramesReceived: 129_600,
            activeStreamNames: ["live/stream1", "live/stream2"],
            sessionMetrics: sessionMetrics,
            timestamp: 1000.0
        )
    }

    @Test("activeSessionCount reflects sessionMetrics count")
    func activeCountMatchesMetrics() {
        let metrics: [String: RTMPServerStatistics.SessionMetrics] = [
            "a": RTMPServerStatistics.SessionMetrics(
                streamName: "stream1", remoteAddress: "1.2.3.4",
                uptimeSeconds: 100, bytesReceived: 1000,
                videoFramesReceived: 500, audioFramesReceived: 1000,
                state: "publishing"
            ),
            "b": RTMPServerStatistics.SessionMetrics(
                streamName: "stream2", remoteAddress: "5.6.7.8",
                uptimeSeconds: 50, bytesReceived: 500,
                videoFramesReceived: 250, audioFramesReceived: 500,
                state: "publishing"
            )
        ]
        let stats = sampleStats(sessionMetrics: metrics)
        #expect(stats.activeSessionCount == 2)
    }

    @Test("sessionMetrics is empty when no sessions")
    func emptyMetrics() {
        let stats = sampleStats()
        #expect(stats.sessionMetrics.isEmpty)
    }

    @Test("SessionMetrics stores all fields")
    func sessionMetricsFields() {
        let sm = RTMPServerStatistics.SessionMetrics(
            streamName: "live/test",
            remoteAddress: "10.0.0.1",
            uptimeSeconds: 300.0,
            bytesReceived: 5000,
            videoFramesReceived: 100,
            audioFramesReceived: 200,
            state: "publishing"
        )
        #expect(sm.streamName == "live/test")
        #expect(sm.remoteAddress == "10.0.0.1")
        #expect(sm.uptimeSeconds == 300.0)
        #expect(sm.bytesReceived == 5000)
        #expect(sm.videoFramesReceived == 100)
        #expect(sm.audioFramesReceived == 200)
        #expect(sm.state == "publishing")
    }

    @Test("totalBytesReceived >= 0")
    func bytesNonNegative() {
        let stats = sampleStats()
        #expect(stats.totalBytesReceived >= 0)
    }

    @Test("activeStreamNames is correct list")
    func streamNames() {
        let stats = sampleStats()
        #expect(stats.activeStreamNames.count == 2)
        #expect(stats.activeStreamNames.contains("live/stream1"))
        #expect(stats.activeStreamNames.contains("live/stream2"))
    }
}
