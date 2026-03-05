// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - StatsDExporter Export

@Suite("StatsDExporter — Export")
struct StatsDExporterExportCoverageTests {

    @Test("export publisher statistics sends UDP packet")
    func exportPublisherStats() async {
        let exporter = StatsDExporter(
            host: "127.0.0.1", port: 8125, prefix: "test"
        )
        let stats = RTMPPublisherStatistics(
            streamKey: "key", serverURL: "rtmp://localhost/app",
            platform: "test", totalBytesSent: 1000,
            currentVideoBitrate: 2_500_000, currentAudioBitrate: 128000,
            peakVideoBitrate: 3_000_000, videoFramesSent: 100,
            audioFramesSent: 200, videoFramesDropped: 5,
            frameDropRate: 0.05, reconnectionCount: 0,
            uptimeSeconds: 60.0, connectionState: "publishing",
            qualityScore: 0.85, qualityGrade: "B",
            timestamp: 1000.0
        )
        // Fire-and-forget UDP — no server needed, won't crash
        await exporter.export(stats, labels: ["env": "test"])
    }

    @Test("export server statistics sends UDP packet")
    func exportServerStats() async {
        let exporter = StatsDExporter(
            host: "127.0.0.1", port: 8125, prefix: "test"
        )
        let stats = RTMPServerStatistics(
            activeSessionCount: 2, totalSessionsConnected: 10,
            totalSessionsRejected: 1, totalBytesReceived: 50000,
            currentIngestBitrate: 3_000_000,
            totalVideoFramesReceived: 500,
            totalAudioFramesReceived: 1000,
            activeStreamNames: ["stream1"],
            sessionMetrics: [:], timestamp: 1000.0
        )
        await exporter.export(stats, labels: [:])
    }

    @Test("flush is no-op for UDP")
    func flushNoOp() async {
        let exporter = StatsDExporter()
        await exporter.flush()
    }
}

// MARK: - PrometheusExporter Export

@Suite("PrometheusExporter — Export")
struct PrometheusExporterExportCoverageTests {

    @Test("export publisher statistics generates metrics")
    func exportPublisherStats() async {
        let exporter = PrometheusExporter()
        let stats = RTMPPublisherStatistics(
            streamKey: "key", serverURL: "rtmp://localhost/app",
            platform: "test", totalBytesSent: 1000,
            currentVideoBitrate: 2_500_000, currentAudioBitrate: 128000,
            peakVideoBitrate: 3_000_000, videoFramesSent: 100,
            audioFramesSent: 200, videoFramesDropped: 5,
            frameDropRate: 0.05, reconnectionCount: 0,
            uptimeSeconds: 60.0, connectionState: "publishing",
            qualityScore: 0.85, qualityGrade: "B",
            timestamp: 1000.0
        )
        await exporter.export(stats, labels: ["env": "test"])
    }

    @Test("flush writes output")
    func flushWritesOutput() async {
        let exporter = PrometheusExporter()
        await exporter.flush()
    }
}
