// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A quality report covering a window of time during a live stream.
///
/// Reports aggregate multiple ``ConnectionQualityScore`` samples
/// and compute trend information over the window.
public struct QualityReport: Sendable {

    /// The time window start (seconds from stream start).
    public let windowStart: Double

    /// The time window end (seconds from stream start).
    public let windowEnd: Double

    /// Quality scores sampled during this window.
    public let samples: [ConnectionQualityScore]

    /// Average score over the window.
    public let averageScore: ConnectionQualityScore

    /// Minimum (worst) score during the window.
    public let minimumScore: ConnectionQualityScore

    /// Maximum (best) score during the window.
    public let maximumScore: ConnectionQualityScore

    /// Quality trend over the window.
    public let trend: Trend

    /// Events that occurred during the window (reconnects, bitrate changes, etc.).
    public let events: [String]

    /// Quality trend direction over a reporting window.
    public enum Trend: String, Sendable {

        /// Overall score improving over the window.
        case improving

        /// Overall score stable (change < 0.05).
        case stable

        /// Overall score degrading over the window.
        case degrading
    }

    /// Creates a quality report from a set of score samples.
    ///
    /// - Parameters:
    ///   - samples: The quality score samples in chronological order.
    ///   - events: Events that occurred during the window.
    /// - Returns: A report, or nil if samples is empty.
    public static func build(
        samples: [ConnectionQualityScore],
        events: [String] = []
    ) -> QualityReport? {
        guard let first = samples.first, let last = samples.last else {
            return nil
        }

        let minSample = samples.min { $0.overall < $1.overall } ?? first
        let maxSample = samples.max { $0.overall < $1.overall } ?? first

        let avgOverall = samples.map(\.overall).reduce(0, +) / Double(samples.count)
        let avgDimensions = averageDimensions(samples)
        let averageScore = ConnectionQualityScore(
            dimensions: avgDimensions,
            overall: avgOverall,
            timestamp: last.timestamp
        )

        let trend = computeTrend(first: first, last: last)

        return QualityReport(
            windowStart: first.timestamp,
            windowEnd: last.timestamp,
            samples: samples,
            averageScore: averageScore,
            minimumScore: minSample,
            maximumScore: maxSample,
            trend: trend,
            events: events
        )
    }

    // MARK: - Private

    private static func computeTrend(
        first: ConnectionQualityScore,
        last: ConnectionQualityScore
    ) -> Trend {
        let delta = last.overall - first.overall
        if delta > 0.05 { return .improving }
        if delta < -0.05 { return .degrading }
        return .stable
    }

    private static func averageDimensions(
        _ samples: [ConnectionQualityScore]
    ) -> [QualityDimension: Double] {
        var sums: [QualityDimension: Double] = [:]
        var counts: [QualityDimension: Int] = [:]
        for sample in samples {
            for (dim, val) in sample.dimensions {
                sums[dim, default: 0] += val
                counts[dim, default: 0] += 1
            }
        }
        var result: [QualityDimension: Double] = [:]
        for (dim, sum) in sums {
            let count = counts[dim] ?? 1
            result[dim] = sum / Double(count)
        }
        return result
    }
}
