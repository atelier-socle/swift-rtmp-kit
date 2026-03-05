// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("StatsDExporter")
struct StatsDExporterTests {

    private let sampleStats = RTMPPublisherStatistics(
        streamKey: "live_abc123",
        serverURL: "rtmp://live.twitch.tv",
        platform: "twitch",
        totalBytesSent: 12_345_678,
        currentVideoBitrate: 4_200_000,
        currentAudioBitrate: 160_000,
        peakVideoBitrate: 6_000_000,
        videoFramesSent: 18_000,
        audioFramesSent: 43_200,
        videoFramesDropped: 3,
        frameDropRate: 0.001,
        reconnectionCount: 1,
        uptimeSeconds: 3600.5,
        qualityScore: 0.91,
        qualityGrade: "excellent",
        timestamp: 1000.0
    )

    private let sampleServerStats = RTMPServerStatistics(
        activeSessionCount: 3,
        totalSessionsConnected: 47,
        totalSessionsRejected: 2,
        totalBytesReceived: 9_876_543,
        currentIngestBitrate: 12_600_000,
        totalVideoFramesReceived: 54_000,
        totalAudioFramesReceived: 129_600,
        activeStreamNames: [],
        sessionMetrics: [:],
        timestamp: 1000.0
    )

    @Test("buildPacket for publisher contains bytes_sent_total counter")
    func publisherBytesCounter() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleStats)
        #expect(
            lines.contains { $0.hasPrefix("rtmp.bytes_sent_total:") && $0.hasSuffix("|c") }
        )
    }

    @Test("gauges use |g suffix")
    func gaugeSuffix() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleStats)
        #expect(
            lines.contains { $0.hasPrefix("rtmp.video_bitrate_bps:") && $0.hasSuffix("|g") }
        )
    }

    @Test("counters use |c suffix")
    func counterSuffix() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleStats)
        let counters = lines.filter { $0.hasSuffix("|c") }
        #expect(counters.count >= 4)
    }

    @Test("custom prefix changes metric names")
    func customPrefix() {
        let exporter = StatsDExporter(prefix: "prod")
        let lines = exporter.buildPacket(sampleStats)
        #expect(
            lines.contains { $0.hasPrefix("prod.bytes_sent_total:") }
        )
        #expect(
            !lines.contains { $0.hasPrefix("rtmp.") }
        )
    }

    @Test("buildPacket for server contains server_active_sessions")
    func serverActiveSessions() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleServerStats)
        #expect(
            lines.contains { $0.hasPrefix("rtmp.server_active_sessions:") }
        )
    }

    @Test("each metric on its own line")
    func oneMetricPerLine() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleStats)
        for line in lines {
            #expect(!line.contains("\n"))
        }
    }

    @Test("no empty lines in packet")
    func noEmptyLines() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleStats)
        #expect(!lines.contains { $0.isEmpty })
    }

    @Test("buildPacket returns non-empty array")
    func nonEmpty() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleStats)
        #expect(!lines.isEmpty)
    }
}
