// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

// MARK: - Fix 6: PrometheusExporter file output

@Suite("Fix 6 — PrometheusExporter file output")
struct PrometheusExporterFileOutputTests {

    private let sampleStats = RTMPPublisherStatistics(
        streamKey: "live_key",
        serverURL: "rtmp://server/app",
        totalBytesSent: 1024,
        currentVideoBitrate: 2_000_000,
        currentAudioBitrate: 128_000,
        peakVideoBitrate: 3_000_000,
        videoFramesSent: 100,
        audioFramesSent: 200,
        videoFramesDropped: 0,
        frameDropRate: 0.0,
        reconnectionCount: 0,
        uptimeSeconds: 60.0,
        qualityScore: nil,
        qualityGrade: nil,
        timestamp: 1000.0
    )

    @Test("outputPath nil defaults to stdout (no file written)")
    func outputPathNilNoFile() {
        let exporter = PrometheusExporter(outputPath: nil)
        #expect(exporter.outputPath == nil)
    }

    @Test("outputPath is stored correctly")
    func outputPathStored() {
        let exporter = PrometheusExporter(outputPath: "/tmp/metrics.prom")
        #expect(exporter.outputPath == "/tmp/metrics.prom")
    }

    @Test("export writes to file when outputPath is set")
    func exportWritesToFile() async throws {
        let path = "/tmp/rtmpkit-test-prometheus-\(ProcessInfo.processInfo.processIdentifier).prom"
        let exporter = PrometheusExporter(outputPath: path)
        await exporter.export(sampleStats, labels: [:])

        let content = try String(contentsOfFile: path, encoding: .utf8)
        #expect(content.contains("rtmp_bytes_sent_total"))
        #expect(content.contains("1024"))

        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("export overwrites file on subsequent calls")
    func exportOverwritesFile() async throws {
        let path = "/tmp/rtmpkit-test-prometheus-overwrite-\(ProcessInfo.processInfo.processIdentifier).prom"
        let exporter = PrometheusExporter(outputPath: path)

        await exporter.export(sampleStats, labels: [:])
        let firstContent = try String(contentsOfFile: path, encoding: .utf8)

        let updatedStats = RTMPPublisherStatistics(
            streamKey: "live_key",
            serverURL: "rtmp://server/app",
            totalBytesSent: 9999,
            currentVideoBitrate: 2_000_000,
            currentAudioBitrate: 128_000,
            peakVideoBitrate: 3_000_000,
            videoFramesSent: 500,
            audioFramesSent: 1000,
            videoFramesDropped: 0,
            frameDropRate: 0.0,
            reconnectionCount: 0,
            uptimeSeconds: 120.0,
            qualityScore: nil,
            qualityGrade: nil,
            timestamp: 2000.0
        )
        await exporter.export(updatedStats, labels: [:])
        let secondContent = try String(contentsOfFile: path, encoding: .utf8)

        #expect(firstContent.contains("1024"))
        #expect(secondContent.contains("9999"))
        #expect(!secondContent.contains("1024"))

        try? FileManager.default.removeItem(atPath: path)
    }
}
