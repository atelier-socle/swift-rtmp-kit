// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A pluggable metrics export backend for RTMPKit.
///
/// Conforming types receive periodic statistics snapshots and
/// export them to external monitoring systems (Prometheus, StatsD, etc.).
///
/// ## Usage
/// ```swift
/// let exporter = PrometheusExporter(prefix: "rtmp")
/// await publisher.setMetricsExporter(exporter, interval: 10.0)
/// ```
public protocol RTMPMetricsExporter: Sendable {

    /// Export publisher statistics.
    ///
    /// - Parameters:
    ///   - statistics: The current publisher metrics snapshot.
    ///   - labels: Additional labels to attach (e.g. `["env": "production"]`).
    func export(
        _ statistics: RTMPPublisherStatistics,
        labels: [String: String]
    ) async

    /// Export server statistics.
    ///
    /// - Parameters:
    ///   - statistics: The current server metrics snapshot.
    ///   - labels: Additional labels to attach.
    func export(
        _ statistics: RTMPServerStatistics,
        labels: [String: String]
    ) async

    /// Flush any buffered metrics. Called on clean shutdown.
    func flush() async
}
