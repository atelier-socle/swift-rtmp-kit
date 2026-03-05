// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPPublisherStatistics — Metrics Snapshot")
struct RTMPPublisherMetricsSnapshotTests {

    private func sampleStats(
        frameDropRate: Double = 0.01,
        qualityScore: Double? = 0.92,
        qualityGrade: String? = "excellent"
    ) -> RTMPPublisherStatistics {
        RTMPPublisherStatistics(
            streamKey: "live_abc123",
            serverURL: "rtmp://live.twitch.tv",
            platform: "twitch",
            totalBytesSent: 52_428_800,
            currentVideoBitrate: 4_200_000,
            currentAudioBitrate: 160_000,
            peakVideoBitrate: 6_000_000,
            videoFramesSent: 18_000,
            audioFramesSent: 43_200,
            videoFramesDropped: 3,
            frameDropRate: frameDropRate,
            reconnectionCount: 0,
            uptimeSeconds: 600.0,
            qualityScore: qualityScore,
            qualityGrade: qualityGrade,
            timestamp: 1000.0
        )
    }

    @Test("all properties stored correctly")
    func allProperties() {
        let stats = sampleStats()
        #expect(stats.streamKey == "live_abc123")
        #expect(stats.serverURL == "rtmp://live.twitch.tv")
        #expect(stats.platform == "twitch")
        #expect(stats.totalBytesSent == 52_428_800)
        #expect(stats.currentVideoBitrate == 4_200_000)
        #expect(stats.currentAudioBitrate == 160_000)
        #expect(stats.peakVideoBitrate == 6_000_000)
        #expect(stats.videoFramesSent == 18_000)
        #expect(stats.audioFramesSent == 43_200)
        #expect(stats.videoFramesDropped == 3)
        #expect(stats.reconnectionCount == 0)
        #expect(stats.uptimeSeconds == 600.0)
    }

    @Test("frameDropRate in range 0.0-1.0")
    func frameDropRateRange() {
        let stats = sampleStats(frameDropRate: 0.05)
        #expect(stats.frameDropRate >= 0.0)
        #expect(stats.frameDropRate <= 1.0)
    }

    @Test("qualityScore nil when not provided")
    func qualityScoreNil() {
        let stats = sampleStats(qualityScore: nil, qualityGrade: nil)
        #expect(stats.qualityScore == nil)
        #expect(stats.qualityGrade == nil)
    }

    @Test("streamKey stored verbatim")
    func streamKeyVerbatim() {
        let stats = sampleStats()
        #expect(stats.streamKey == "live_abc123")
    }

    @Test("timestamp is positive")
    func timestampPositive() {
        let stats = sampleStats()
        #expect(stats.timestamp > 0)
    }
}
