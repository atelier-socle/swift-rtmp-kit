// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("PrometheusExporter")
struct PrometheusExporterTests {

    private let sampleStats = RTMPPublisherStatistics(
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
        totalBytesReceived: 9_876_543_210,
        currentIngestBitrate: 12_600_000,
        totalVideoFramesReceived: 54_000,
        totalAudioFramesReceived: 129_600,
        activeStreamNames: ["live/stream1"],
        sessionMetrics: [:],
        timestamp: 1000.0
    )

    @Test("output contains rtmp_bytes_sent_total")
    func bytesSentTotal() {
        let exporter = PrometheusExporter()
        let output = exporter.render(sampleStats, labels: [:])
        #expect(output.contains("rtmp_bytes_sent_total"))
    }

    @Test("output contains rtmp_video_bitrate_bps")
    func videoBitrate() {
        let exporter = PrometheusExporter()
        let output = exporter.render(sampleStats, labels: [:])
        #expect(output.contains("rtmp_video_bitrate_bps"))
    }

    @Test("output contains HELP line for each metric")
    func helpLines() {
        let exporter = PrometheusExporter()
        let output = exporter.render(sampleStats, labels: [:])
        #expect(output.contains("# HELP rtmp_bytes_sent_total"))
        #expect(output.contains("# HELP rtmp_video_bitrate_bps"))
    }

    @Test("output contains TYPE line for each metric")
    func typeLines() {
        let exporter = PrometheusExporter()
        let output = exporter.render(sampleStats, labels: [:])
        #expect(output.contains("# TYPE rtmp_bytes_sent_total counter"))
        #expect(output.contains("# TYPE rtmp_video_bitrate_bps gauge"))
    }

    @Test("labels appear in {key=value} format")
    func labelsFormat() {
        let exporter = PrometheusExporter()
        let output = exporter.render(
            sampleStats, labels: ["env": "production"]
        )
        #expect(output.contains("env=\"production\""))
    }

    @Test("counter metrics use _total suffix")
    func counterSuffix() {
        let exporter = PrometheusExporter()
        let output = exporter.render(sampleStats, labels: [:])
        #expect(output.contains("rtmp_bytes_sent_total"))
        #expect(output.contains("rtmp_video_frames_sent_total"))
        #expect(output.contains("rtmp_reconnection_count_total"))
    }

    @Test("gauge metrics do NOT use _total suffix")
    func gaugeNoSuffix() {
        let exporter = PrometheusExporter()
        let output = exporter.render(sampleStats, labels: [:])
        #expect(output.contains("rtmp_video_bitrate_bps{"))
        #expect(output.contains("rtmp_uptime_seconds{"))
    }

    @Test("custom prefix changes metric names")
    func customPrefix() {
        let exporter = PrometheusExporter(prefix: "myapp")
        let output = exporter.render(sampleStats, labels: [:])
        #expect(output.contains("myapp_bytes_sent_total"))
        #expect(!output.contains("rtmp_bytes_sent_total"))
    }

    @Test("qualityScore nil omits metric line")
    func qualityScoreNilOmitted() {
        let stats = RTMPPublisherStatistics(
            streamKey: "key", serverURL: "url",
            totalBytesSent: 0, currentVideoBitrate: 0,
            currentAudioBitrate: 0, peakVideoBitrate: 0,
            videoFramesSent: 0, audioFramesSent: 0,
            videoFramesDropped: 0, frameDropRate: 0,
            reconnectionCount: 0, uptimeSeconds: 0,
            qualityScore: nil, qualityGrade: nil,
            timestamp: 0
        )
        let exporter = PrometheusExporter()
        let output = exporter.render(stats, labels: [:])
        #expect(!output.contains("quality_score"))
    }

    @Test("server output contains rtmp_server_active_sessions")
    func serverActiveSessions() {
        let exporter = PrometheusExporter()
        let output = exporter.render(sampleServerStats, labels: [:])
        #expect(output.contains("rtmp_server_active_sessions"))
        #expect(output.contains("3"))
    }

    @Test("server output contains rtmp_server_bytes_received_total")
    func serverBytesReceived() {
        let exporter = PrometheusExporter()
        let output = exporter.render(sampleServerStats, labels: [:])
        #expect(output.contains("rtmp_server_bytes_received_total"))
    }

    @Test("output ends with newline")
    func endsWithNewline() {
        let exporter = PrometheusExporter()
        let output = exporter.render(sampleStats, labels: [:])
        #expect(output.hasSuffix("\n"))
    }
}
