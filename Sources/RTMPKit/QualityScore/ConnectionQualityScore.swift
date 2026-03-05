// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A composite quality score for a live RTMP connection.
///
/// Scores are in the range 0.0–1.0 where higher is better.
/// The ``overall`` score is a weighted average of all dimension scores.
public struct ConnectionQualityScore: Sendable {

    /// Per-dimension scores. Each value is in 0.0–1.0.
    public let dimensions: [QualityDimension: Double]

    /// Weighted composite score across all dimensions (0.0–1.0).
    public let overall: Double

    /// Qualitative grade derived from the overall score.
    public let grade: Grade

    /// Timestamp of this score (continuous time, seconds).
    public let timestamp: Double

    /// Creates a quality score from per-dimension values.
    ///
    /// - Parameters:
    ///   - dimensions: Per-dimension scores (each 0.0–1.0).
    ///   - timestamp: Time of this measurement.
    public init(dimensions: [QualityDimension: Double], timestamp: Double) {
        self.dimensions = dimensions
        self.timestamp = timestamp
        self.overall = Self.computeOverall(dimensions)
        self.grade = Grade.from(overall: self.overall)
    }

    /// Creates a quality score with an explicit overall value.
    ///
    /// - Parameters:
    ///   - dimensions: Per-dimension scores (each 0.0–1.0).
    ///   - overall: Pre-computed overall score.
    ///   - timestamp: Time of this measurement.
    public init(
        dimensions: [QualityDimension: Double],
        overall: Double,
        timestamp: Double
    ) {
        self.dimensions = dimensions
        self.overall = overall
        self.grade = Grade.from(overall: overall)
        self.timestamp = timestamp
    }

    /// Returns the score for a specific dimension, or nil if not measured.
    ///
    /// - Parameter dimension: The quality dimension to look up.
    /// - Returns: The score (0.0–1.0) or nil.
    public func score(for dimension: QualityDimension) -> Double? {
        dimensions[dimension]
    }

    /// True if any dimension score is below 0.40.
    public var hasWarning: Bool {
        dimensions.values.contains { $0 < 0.40 }
    }

    /// Dimensions with scores below 0.40 (problem areas).
    public var weakDimensions: [QualityDimension] {
        dimensions.filter { $0.value < 0.40 }.map(\.key)
    }

    // MARK: - Grade

    /// Qualitative grade derived from the overall quality score.
    public enum Grade: String, Sendable, Comparable, CaseIterable {

        /// Overall score >= 0.85.
        case excellent

        /// Overall score >= 0.70.
        case good

        /// Overall score >= 0.50.
        case fair

        /// Overall score >= 0.30.
        case poor

        /// Overall score < 0.30.
        case critical

        /// Comparable: excellent > good > fair > poor > critical.
        public static func < (lhs: Grade, rhs: Grade) -> Bool {
            lhs.ordinal < rhs.ordinal
        }

        /// Derive a grade from an overall score value.
        ///
        /// - Parameter overall: The overall quality score (0.0–1.0).
        /// - Returns: The corresponding grade.
        public static func from(overall: Double) -> Grade {
            if overall >= 0.85 { return .excellent }
            if overall >= 0.70 { return .good }
            if overall >= 0.50 { return .fair }
            if overall >= 0.30 { return .poor }
            return .critical
        }

        /// Ordinal value for comparison (higher = better).
        internal var ordinal: Int {
            switch self {
            case .critical: 0
            case .poor: 1
            case .fair: 2
            case .good: 3
            case .excellent: 4
            }
        }
    }

    // MARK: - Private

    private static func computeOverall(
        _ dimensions: [QualityDimension: Double]
    ) -> Double {
        var weightedSum = 0.0
        var totalWeight = 0.0
        for (dimension, value) in dimensions {
            let clamped = max(0.0, min(1.0, value))
            weightedSum += clamped * dimension.weight
            totalWeight += dimension.weight
        }
        guard totalWeight > 0 else { return 0.0 }
        return weightedSum / totalWeight
    }
}
