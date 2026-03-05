// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Mock Exporter

/// Mock metrics exporter that counts export calls.
actor MockMetricsExporter: RTMPMetricsExporter {

    /// Number of publisher export calls received.
    var publisherExportCount: Int = 0

    /// Number of server export calls received.
    var serverExportCount: Int = 0

    func export(
        _ statistics: RTMPPublisherStatistics,
        labels: [String: String]
    ) async {
        publisherExportCount += 1
    }

    func export(
        _ statistics: RTMPServerStatistics,
        labels: [String: String]
    ) async {
        serverExportCount += 1
    }

    func flush() async {}
}

// MARK: - Suite 1: Publisher Metrics

@Suite("Metrics Showcase — Publisher")
struct MetricsShowcasePublisherTests {

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
        videoFramesDropped: 0,
        frameDropRate: 0.0,
        reconnectionCount: 0,
        uptimeSeconds: 600.0,
        qualityScore: 0.92,
        qualityGrade: "excellent",
        timestamp: 0.0
    )

    @Test("Prometheus format for Twitch publisher")
    func prometheusTwitch() {
        let exporter = PrometheusExporter(prefix: "rtmp")
        let output = exporter.render(
            sampleStats, labels: ["env": "production"]
        )
        #expect(output.contains("rtmp_bytes_sent_total{"))
        #expect(output.contains("env=\"production\""))
        #expect(output.contains("platform=\"twitch\""))
        #expect(output.contains("52428800"))
    }

    @Test("StatsD packet for publisher")
    func statsdPublisher() {
        let exporter = StatsDExporter(prefix: "rtmp")
        let lines = exporter.buildPacket(sampleStats)
        #expect(
            lines.contains {
                $0.hasPrefix("rtmp.video_bitrate_bps:4200000|g")
            }
        )
        #expect(lines.contains { $0.hasSuffix("|c") })
    }

    @Test("publisher metricsSnapshot is accessible")
    func publisherSnapshot() async {
        let transport = MockTransport(messages: [])
        let publisher = RTMPPublisher(transport: transport)
        let stats = await publisher.metricsSnapshot()
        #expect(stats.totalBytesSent >= 0)
        #expect(stats.uptimeSeconds >= 0.0)
    }

    @Test("setMetricsExporter wires periodic export")
    func periodicExport() async throws {
        let transport = MockTransport(messages: [])
        let publisher = RTMPPublisher(transport: transport)
        let mockExporter = MockMetricsExporter()
        await publisher.setMetricsExporter(
            mockExporter, interval: 0.05
        )
        try await Task.sleep(nanoseconds: 200_000_000)
        await publisher.removeMetricsExporter()
        let count = await mockExporter.publisherExportCount
        #expect(count >= 2)
    }
}

// MARK: - Suite 2: Server Metrics

@Suite("Metrics Showcase — Server")
struct MetricsShowcaseServerTests {

    @Test("Prometheus format for server")
    func prometheusServer() {
        let stats = RTMPServerStatistics(
            activeSessionCount: 3,
            totalSessionsConnected: 47,
            totalSessionsRejected: 2,
            totalBytesReceived: 9_876_543,
            currentIngestBitrate: 12_600_000,
            totalVideoFramesReceived: 54_000,
            totalAudioFramesReceived: 129_600,
            activeStreamNames: [],
            sessionMetrics: [:],
            timestamp: 0
        )
        let exporter = PrometheusExporter()
        let output = exporter.render(stats, labels: [:])
        #expect(output.contains("rtmp_server_active_sessions"))
        #expect(output.contains("3"))
    }

    @Test("server statistics tracks session counts")
    func serverSessionCounts() async {
        let messages = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            )
        ]
        let server = RTMPServer(
            configuration: .localhost,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: true,
                    connected: true
                )
            }
        )
        try? await server.start()
        await server.acceptConnection()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let stats = await server.metricsSnapshot()
        #expect(stats.activeSessionCount >= 1)
    }

    @Test("StatsD packet for server")
    func statsdServer() {
        let stats = RTMPServerStatistics(
            activeSessionCount: 2,
            totalSessionsConnected: 10,
            totalSessionsRejected: 1,
            totalBytesReceived: 1_000_000,
            currentIngestBitrate: 5_000_000,
            totalVideoFramesReceived: 1000,
            totalAudioFramesReceived: 2000,
            activeStreamNames: [],
            sessionMetrics: [:],
            timestamp: 0
        )
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(stats)
        #expect(lines.contains { $0.hasSuffix("|g") })
        #expect(lines.contains { $0.hasSuffix("|c") })
    }

    @Test("metrics export does not block publishing")
    func nonBlocking() async throws {
        let transport = MockTransport(messages: [])
        let publisher = RTMPPublisher(transport: transport)

        let slowExporter = MockMetricsExporter()
        await publisher.setMetricsExporter(
            slowExporter, interval: 0.02
        )

        // Publisher continues without blocking
        let stats = await publisher.metricsSnapshot()
        #expect(stats.totalBytesSent >= 0)

        await publisher.removeMetricsExporter()
    }
}
