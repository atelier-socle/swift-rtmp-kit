// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// Exports RTMPKit metrics to a StatsD server via UDP.
///
/// Supports Etsy StatsD protocol (gauge `|g`, counter `|c`).
/// UDP send is fire-and-forget: failures are silently ignored.
///
/// ## Usage
/// ```swift
/// let exporter = StatsDExporter(host: "127.0.0.1", port: 8125)
/// await exporter.export(stats, labels: [:])
/// ```
public struct StatsDExporter: RTMPMetricsExporter, Sendable {

    /// StatsD server host. Default: "127.0.0.1".
    public let host: String

    /// StatsD server port. Default: 8125.
    public let port: Int

    /// Metric name prefix. Default: "rtmp".
    public let prefix: String

    /// Creates a StatsD exporter.
    ///
    /// - Parameters:
    ///   - host: StatsD server host. Default: "127.0.0.1".
    ///   - port: StatsD server port. Default: 8125.
    ///   - prefix: Metric name prefix. Default: "rtmp".
    public init(
        host: String = "127.0.0.1",
        port: Int = 8125,
        prefix: String = "rtmp"
    ) {
        self.host = host
        self.port = port
        self.prefix = prefix
    }

    // MARK: - RTMPMetricsExporter

    /// Export publisher statistics via UDP.
    public func export(
        _ statistics: RTMPPublisherStatistics,
        labels: [String: String]
    ) async {
        let lines = buildPacket(statistics)
        let payload = lines.joined(separator: "\n")
        sendUDP(payload, host: host, port: port)
    }

    /// Export server statistics via UDP.
    public func export(
        _ statistics: RTMPServerStatistics,
        labels: [String: String]
    ) async {
        let lines = buildPacket(statistics)
        let payload = lines.joined(separator: "\n")
        sendUDP(payload, host: host, port: port)
    }

    /// Flush is a no-op for fire-and-forget UDP.
    public func flush() async {}

    // MARK: - Packet Building

    /// Build StatsD UDP packet lines for publisher statistics.
    ///
    /// - Parameter statistics: The publisher metrics snapshot.
    /// - Returns: Array of StatsD-format metric lines.
    internal func buildPacket(
        _ statistics: RTMPPublisherStatistics
    ) -> [String] {
        var lines: [String] = []
        lines.append(
            "\(prefix).bytes_sent_total:\(statistics.totalBytesSent)|c"
        )
        lines.append(
            "\(prefix).video_bitrate_bps:\(statistics.currentVideoBitrate)|g"
        )
        lines.append(
            "\(prefix).audio_bitrate_bps:\(statistics.currentAudioBitrate)|g"
        )
        lines.append(
            "\(prefix).video_frames_sent_total:\(statistics.videoFramesSent)|c"
        )
        lines.append(
            "\(prefix).audio_frames_sent_total:\(statistics.audioFramesSent)|c"
        )
        lines.append(
            "\(prefix).video_frames_dropped_total:\(statistics.videoFramesDropped)|c"
        )
        lines.append(
            "\(prefix).frame_drop_rate:\(formatDouble(statistics.frameDropRate))|g"
        )
        lines.append(
            "\(prefix).reconnection_count_total:\(statistics.reconnectionCount)|c"
        )
        lines.append(
            "\(prefix).uptime_seconds:\(formatDouble(statistics.uptimeSeconds))|g"
        )
        if let score = statistics.qualityScore {
            lines.append(
                "\(prefix).quality_score:\(formatDouble(score))|g"
            )
        }
        lines.append(
            "\(prefix).peak_video_bitrate_bps:\(statistics.peakVideoBitrate)|g"
        )
        return lines
    }

    /// Build StatsD UDP packet lines for server statistics.
    ///
    /// - Parameter statistics: The server metrics snapshot.
    /// - Returns: Array of StatsD-format metric lines.
    internal func buildPacket(
        _ statistics: RTMPServerStatistics
    ) -> [String] {
        var lines: [String] = []
        lines.append(
            "\(prefix).server_active_sessions:\(statistics.activeSessionCount)|g"
        )
        lines.append(
            "\(prefix).server_total_sessions:\(statistics.totalSessionsConnected)|c"
        )
        lines.append(
            "\(prefix).server_rejected_sessions:\(statistics.totalSessionsRejected)|c"
        )
        lines.append(
            "\(prefix).server_bytes_received:\(statistics.totalBytesReceived)|c"
        )
        lines.append(
            "\(prefix).server_ingest_bitrate_bps:\(statistics.currentIngestBitrate)|g"
        )
        lines.append(
            "\(prefix).server_video_frames:\(statistics.totalVideoFramesReceived)|c"
        )
        lines.append(
            "\(prefix).server_audio_frames:\(statistics.totalAudioFramesReceived)|c"
        )
        return lines
    }

    // MARK: - Private

    private func formatDouble(_ value: Double) -> String {
        if value == value.rounded() && value < 1_000_000_000 {
            return String(format: "%.1f", value)
        }
        return String(value)
    }

    private func sendUDP(_ data: String, host: String, port: Int) {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)

        let bytes = Array(data.utf8)
        withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                _ = sendto(
                    fd, bytes, bytes.count, 0,
                    sa, socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
    }
}
