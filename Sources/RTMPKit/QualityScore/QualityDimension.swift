// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A single dimension of connection quality assessment.
///
/// Each dimension measures a specific aspect of the connection and
/// contributes to the overall ``ConnectionQualityScore`` with a
/// predefined weight.
public enum QualityDimension: String, Sendable, CaseIterable, Hashable {

    /// Network throughput relative to target bitrate.
    case throughput

    /// Round-trip time stability.
    case latency

    /// Frame drop rate.
    case frameDropRate

    /// Reconnection frequency.
    case stability

    /// Bitrate achievement (actual vs configured).
    case bitrateAchievement

    /// The weight of this dimension in the overall quality score.
    public var weight: Double {
        switch self {
        case .throughput: 0.30
        case .latency: 0.25
        case .frameDropRate: 0.20
        case .stability: 0.15
        case .bitrateAchievement: 0.10
        }
    }
}
