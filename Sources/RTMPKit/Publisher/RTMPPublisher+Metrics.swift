// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch

/// Batched metrics context to minimise actor hops during periodic export.
struct MetricsContext {
    let stats: RTMPPublisherStatistics
    let exporter: (any RTMPMetricsExporter)?
    let labels: [String: String]
}

extension RTMPPublisher {

    /// Attach a metrics exporter with periodic export.
    ///
    /// Performs an immediate first export inline (no Task scheduling
    /// delay), then fires subsequent exports every `interval` seconds.
    /// Call before or after `publish()`.
    ///
    /// - Parameters:
    ///   - exporter: The metrics exporter backend.
    ///   - interval: Export interval in seconds. Default: 10.0.
    ///   - labels: Additional labels to attach. Default: empty.
    public func setMetricsExporter(
        _ exporter: any RTMPMetricsExporter,
        interval: Double = 10.0,
        labels: [String: String] = [:]
    ) async {
        metricsExporter = exporter
        metricsLabels = labels
        metricsTask?.cancel()

        // First export fires inline — no Task scheduling delay.
        let stats = await metricsSnapshot()
        await exporter.export(stats, labels: labels)

        // Subsequent exports via periodic timer.
        metricsTask = Task { [weak self] in
            let intervalNs = UInt64(interval * 1_000_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                let context = await self.metricsContext()
                await context.exporter?.export(
                    context.stats, labels: context.labels
                )
                try? await Task.sleep(nanoseconds: intervalNs)
            }
        }
    }

    /// Export a final metrics snapshot and flush the exporter.
    ///
    /// Call this before `disconnect()` to guarantee at least one
    /// metrics export, even for short streaming sessions.
    public func flushMetrics() async {
        if let exporter = metricsExporter {
            let stats = await metricsSnapshot()
            await exporter.export(stats, labels: metricsLabels)
            await exporter.flush()
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

    /// Capture metrics context in a single actor entry for periodic export.
    func metricsContext() async -> MetricsContext {
        let stats = await metricsSnapshot()
        return MetricsContext(
            stats: stats,
            exporter: metricsExporter,
            labels: metricsLabels
        )
    }

    /// Generate a statistics snapshot of the current publisher state.
    ///
    /// - Returns: A point-in-time publisher metrics snapshot.
    public func metricsSnapshot() async -> RTMPPublisherStatistics {
        let connStats = statistics
        let now = Double(monotonicNow()) / 1_000_000_000.0
        let config = currentConfiguration
        let qScore = await qualityMonitor?.currentScore

        return RTMPPublisherStatistics(
            streamKey: config?.streamKey ?? "",
            serverURL: config?.url ?? "",
            platform: config?.preset?.platformName,
            totalBytesSent: Int(connStats.bytesSent),
            currentVideoBitrate: liveVideoBitrate,
            currentAudioBitrate: 0,
            peakVideoBitrate: liveVideoBitrate,
            videoFramesSent: Int(connStats.videoFramesSent),
            audioFramesSent: Int(connStats.audioFramesSent),
            videoFramesDropped: Int(connStats.droppedFrames),
            frameDropRate: connStats.dropRate / 100.0,
            reconnectionCount: 0,
            uptimeSeconds: connStats.connectionUptime,
            connectionState: "\(state)",
            qualityScore: qScore?.overall,
            qualityGrade: qScore?.grade.rawValue,
            timestamp: now
        )
    }
}
