// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Fix D: StatsD packet building

@Suite("Fix D — StatsDExporter packet content")
struct StatsDExporterPacketTests {

    private let sampleStats = RTMPPublisherStatistics(
        streamKey: "live_key",
        serverURL: "rtmp://server/app",
        totalBytesSent: 1024,
        currentVideoBitrate: 2_000_000,
        currentAudioBitrate: 128_000,
        peakVideoBitrate: 3_000_000,
        videoFramesSent: 100,
        audioFramesSent: 200,
        videoFramesDropped: 2,
        frameDropRate: 0.02,
        reconnectionCount: 0,
        uptimeSeconds: 30.0,
        qualityScore: nil,
        qualityGrade: nil,
        timestamp: 1000.0
    )

    @Test("buildPacket returns non-empty lines")
    func buildPacketNonEmpty() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleStats)
        #expect(!lines.isEmpty)
    }

    @Test("buildPacket contains counter and gauge types")
    func buildPacketTypes() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleStats)
        let hasCounter = lines.contains { $0.hasSuffix("|c") }
        let hasGauge = lines.contains { $0.hasSuffix("|g") }
        #expect(hasCounter)
        #expect(hasGauge)
    }

    @Test("buildPacket uses configured prefix")
    func buildPacketPrefix() {
        let exporter = StatsDExporter(prefix: "myapp")
        let lines = exporter.buildPacket(sampleStats)
        #expect(lines.allSatisfy { $0.hasPrefix("myapp.") })
    }

    @Test("buildPacket contains bytes_sent_total metric")
    func buildPacketBytesSent() {
        let exporter = StatsDExporter()
        let lines = exporter.buildPacket(sampleStats)
        let bytesSent = lines.first { $0.hasPrefix("rtmp.bytes_sent_total") }
        #expect(bytesSent?.contains("1024") == true)
    }
}
