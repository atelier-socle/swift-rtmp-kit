// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Exports RTMPKit metrics in Prometheus text exposition format.
///
/// Output is pure text — pipe to any HTTP server or write to a file
/// served by a `node_exporter` textfile collector.
///
/// ## Usage
/// ```swift
/// let exporter = PrometheusExporter(prefix: "rtmp")
/// let output = exporter.render(stats, labels: ["env": "prod"])
/// ```
public struct PrometheusExporter: RTMPMetricsExporter, Sendable {

    /// Metric name prefix. Default: "rtmp".
    public let prefix: String

    /// Optional file path for writing metrics. When set, metrics are
    /// written to this file instead of stdout.
    public let outputPath: String?

    /// Creates a Prometheus exporter.
    ///
    /// - Parameters:
    ///   - prefix: Metric name prefix. Default: "rtmp".
    ///   - outputPath: File path for writing metrics. If `nil`, prints to stdout.
    public init(prefix: String = "rtmp", outputPath: String? = nil) {
        self.prefix = prefix
        self.outputPath = outputPath
    }

    // MARK: - RTMPMetricsExporter

    /// Export publisher statistics.
    public func export(
        _ statistics: RTMPPublisherStatistics,
        labels: [String: String]
    ) async {
        let text = render(statistics, labels: labels)
        writeOutput(text)
    }

    /// Export server statistics.
    public func export(
        _ statistics: RTMPServerStatistics,
        labels: [String: String]
    ) async {
        let text = render(statistics, labels: labels)
        writeOutput(text)
    }

    /// Flush is a no-op for the Prometheus exporter.
    public func flush() async {}

    // MARK: - Output

    private func writeOutput(_ text: String) {
        if let path = outputPath {
            try? text.write(
                toFile: path, atomically: true, encoding: .utf8
            )
        } else {
            print(text, terminator: "")
        }
    }

    // MARK: - Rendering

    /// Render publisher statistics as Prometheus text format.
    ///
    /// - Parameters:
    ///   - statistics: The publisher metrics snapshot.
    ///   - labels: Additional labels to include.
    /// - Returns: Prometheus exposition text.
    public func render(
        _ statistics: RTMPPublisherStatistics,
        labels: [String: String]
    ) -> String {
        var allLabels = labels
        allLabels["server"] = statistics.serverURL
        if let platform = statistics.platform {
            allLabels["platform"] = platform
        }
        let labelStr = formatLabels(allLabels)

        var entries = publisherMetricEntries(statistics)
        if let score = statistics.qualityScore {
            entries.append(
                MetricEntry(
                    name: "\(prefix)_quality_score",
                    help: "Current connection quality score (0.0-1.0).",
                    type: "gauge", value: formatDouble(score)
                ))
        }

        return renderEntries(entries, labels: labelStr)
    }

    /// Render server statistics as Prometheus text format.
    ///
    /// - Parameters:
    ///   - statistics: The server metrics snapshot.
    ///   - labels: Additional labels to include.
    /// - Returns: Prometheus exposition text.
    public func render(
        _ statistics: RTMPServerStatistics,
        labels: [String: String]
    ) -> String {
        let labelStr = labels.isEmpty ? "" : formatLabels(labels)
        let entries = serverMetricEntries(statistics)
        return renderEntries(entries, labels: labelStr)
    }

    // MARK: - Private

    private struct MetricEntry {
        let name: String
        let help: String
        let type: String
        let value: String
    }

    private func publisherMetricEntries(
        _ s: RTMPPublisherStatistics
    ) -> [MetricEntry] {
        [
            MetricEntry(
                name: "\(prefix)_bytes_sent_total",
                help: "Total bytes sent to RTMP server.",
                type: "counter", value: "\(s.totalBytesSent)"),
            MetricEntry(
                name: "\(prefix)_video_bitrate_bps",
                help: "Current video bitrate in bits per second.",
                type: "gauge", value: "\(s.currentVideoBitrate)"),
            MetricEntry(
                name: "\(prefix)_audio_bitrate_bps",
                help: "Current audio bitrate in bits per second.",
                type: "gauge", value: "\(s.currentAudioBitrate)"),
            MetricEntry(
                name: "\(prefix)_video_frames_sent_total",
                help: "Total video frames sent.",
                type: "counter", value: "\(s.videoFramesSent)"),
            MetricEntry(
                name: "\(prefix)_audio_frames_sent_total",
                help: "Total audio frames sent.",
                type: "counter", value: "\(s.audioFramesSent)"),
            MetricEntry(
                name: "\(prefix)_video_frames_dropped_total",
                help: "Total video frames dropped.",
                type: "counter", value: "\(s.videoFramesDropped)"),
            MetricEntry(
                name: "\(prefix)_frame_drop_rate",
                help: "Current frame drop rate (0.0-1.0).",
                type: "gauge", value: formatDouble(s.frameDropRate)),
            MetricEntry(
                name: "\(prefix)_reconnection_count_total",
                help: "Total reconnection attempts.",
                type: "counter", value: "\(s.reconnectionCount)"),
            MetricEntry(
                name: "\(prefix)_uptime_seconds",
                help: "Stream uptime in seconds.",
                type: "gauge", value: formatDouble(s.uptimeSeconds)),
            MetricEntry(
                name: "\(prefix)_peak_video_bitrate_bps",
                help: "Peak video bitrate observed (bps).",
                type: "gauge", value: "\(s.peakVideoBitrate)")
        ]
    }

    private func serverMetricEntries(
        _ s: RTMPServerStatistics
    ) -> [MetricEntry] {
        [
            MetricEntry(
                name: "\(prefix)_server_active_sessions",
                help: "Current number of active publisher sessions.",
                type: "gauge", value: "\(s.activeSessionCount)"),
            MetricEntry(
                name: "\(prefix)_server_total_sessions_total",
                help: "Total sessions connected since start.",
                type: "counter", value: "\(s.totalSessionsConnected)"),
            MetricEntry(
                name: "\(prefix)_server_rejected_sessions_total",
                help: "Total sessions rejected.",
                type: "counter", value: "\(s.totalSessionsRejected)"),
            MetricEntry(
                name: "\(prefix)_server_bytes_received_total",
                help: "Total bytes received from all publishers.",
                type: "counter", value: "\(s.totalBytesReceived)"),
            MetricEntry(
                name: "\(prefix)_server_ingest_bitrate_bps",
                help: "Current total ingest bitrate (bps).",
                type: "gauge", value: "\(s.currentIngestBitrate)"),
            MetricEntry(
                name: "\(prefix)_server_video_frames_total",
                help: "Total video frames received.",
                type: "counter", value: "\(s.totalVideoFramesReceived)"),
            MetricEntry(
                name: "\(prefix)_server_audio_frames_total",
                help: "Total audio frames received.",
                type: "counter", value: "\(s.totalAudioFramesReceived)")
        ]
    }

    private func renderEntries(
        _ entries: [MetricEntry], labels: String
    ) -> String {
        var lines: [String] = []
        for entry in entries {
            lines.append("# HELP \(entry.name) \(entry.help)")
            lines.append("# TYPE \(entry.name) \(entry.type)")
            if labels.isEmpty {
                lines.append("\(entry.name) \(entry.value)")
            } else {
                lines.append("\(entry.name){\(labels)} \(entry.value)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func formatLabels(_ labels: [String: String]) -> String {
        labels.sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\"\(escapeLabel($0.value))\"" }
            .joined(separator: ",")
    }

    private func escapeLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func formatDouble(_ value: Double) -> String {
        if value == value.rounded() && value < 1_000_000_000 {
            return String(format: "%.1f", value)
        }
        return String(value)
    }
}
