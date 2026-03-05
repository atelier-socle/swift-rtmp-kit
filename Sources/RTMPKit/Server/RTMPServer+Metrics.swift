// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch

extension RTMPServer {

    /// Attach a metrics exporter with periodic export.
    ///
    /// Server statistics are pushed every `interval` seconds to the exporter.
    ///
    /// - Parameters:
    ///   - exporter: The metrics exporter backend.
    ///   - interval: Export interval in seconds. Default: 10.0.
    ///   - labels: Additional labels to attach. Default: empty.
    public func setMetricsExporter(
        _ exporter: any RTMPMetricsExporter,
        interval: Double = 10.0,
        labels: [String: String] = [:]
    ) {
        metricsExporter = exporter
        metricsLabels = labels
        metricsTask?.cancel()
        metricsTask = Task { [weak self] in
            let intervalNs = UInt64(interval * 1_000_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNs)
                guard !Task.isCancelled else { return }
                guard let self else { return }
                let stats = await self.metricsSnapshot()
                let exp = await self.metricsExporter
                let lbl = await self.metricsLabels
                await exp?.export(stats, labels: lbl)
            }
        }
    }

    /// Remove the metrics exporter and stop periodic export.
    public func removeMetricsExporter() async {
        metricsTask?.cancel()
        metricsTask = nil
        await metricsExporter?.flush()
        metricsExporter = nil
        metricsLabels = [:]
    }

    /// Generate a statistics snapshot of the current server state.
    ///
    /// - Returns: A point-in-time server metrics snapshot.
    public func metricsSnapshot() async -> RTMPServerStatistics {
        let now = currentTime()

        var sessionDetails: [String: RTMPServerStatistics.SessionMetrics] = [:]
        var streamNames: [String] = []

        for (id, session) in sessions {
            let sName = await session.streamName
            let remote = session.remoteAddress
            let uptime = now - session.connectedAt
            let bytes = await session.bytesReceived
            let video = await session.videoFramesReceived
            let audio = await session.audioFramesReceived
            let state = await session.state

            sessionDetails[id.uuidString] =
                RTMPServerStatistics.SessionMetrics(
                    streamName: sName,
                    remoteAddress: remote,
                    uptimeSeconds: uptime,
                    bytesReceived: bytes,
                    videoFramesReceived: video,
                    audioFramesReceived: audio,
                    state: "\(state)"
                )

            if let sName {
                streamNames.append(sName)
            }
        }

        return RTMPServerStatistics(
            activeSessionCount: sessions.count,
            totalSessionsConnected: totalSessionsConnected,
            totalSessionsRejected: totalSessionsRejected,
            totalBytesReceived: totalBytesReceived,
            currentIngestBitrate: 0,
            totalVideoFramesReceived: totalVideoFramesReceived,
            totalAudioFramesReceived: totalAudioFramesReceived,
            activeStreamNames: streamNames,
            sessionMetrics: sessionDetails,
            timestamp: now
        )
    }

    /// Increment the connected sessions counter.
    func recordSessionConnected() {
        totalSessionsConnected += 1
    }

    /// Increment the rejected sessions counter.
    func recordSessionRejected() {
        totalSessionsRejected += 1
    }
}
