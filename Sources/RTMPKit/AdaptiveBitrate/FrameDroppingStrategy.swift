// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Determines the priority order for dropping frames under congestion,
/// maintaining GOP coherence.
///
/// Use one of the built-in presets (``default``, ``aggressive``, ``conservative``)
/// or create a custom strategy with specific thresholds.
public struct FrameDroppingStrategy: Sendable, Equatable {

    /// Drop order priority (lowest raw value = dropped first).
    public enum FramePriority: Int, Sendable, Comparable, CaseIterable {

        /// B-frame — lowest priority, dropped first.
        case bFrame = 0

        /// P-frame — medium priority.
        case pFrame = 1

        /// I-frame (keyframe) — highest priority, dropped last.
        case iFrame = 2

        public static func < (lhs: FramePriority, rhs: FramePriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Maximum number of consecutive non-keyframe drops before forcing a frame through.
    public var maxConsecutiveNonKeyframeDrops: Int

    /// When `true`, the strategy requests a new keyframe after dropping
    /// ``maxConsecutiveNonKeyframeDrops`` consecutive non-keyframes.
    public var requestKeyframeAfterMaxDrops: Bool

    /// Creates a frame dropping strategy with explicit parameters.
    ///
    /// - Parameters:
    ///   - maxConsecutiveNonKeyframeDrops: Maximum consecutive non-keyframe drops.
    ///   - requestKeyframeAfterMaxDrops: Whether to request a keyframe after max drops.
    public init(maxConsecutiveNonKeyframeDrops: Int, requestKeyframeAfterMaxDrops: Bool) {
        self.maxConsecutiveNonKeyframeDrops = maxConsecutiveNonKeyframeDrops
        self.requestKeyframeAfterMaxDrops = requestKeyframeAfterMaxDrops
    }

    /// Default strategy — balanced between quality and recovery.
    public static let `default` = FrameDroppingStrategy(
        maxConsecutiveNonKeyframeDrops: 30,
        requestKeyframeAfterMaxDrops: true
    )

    /// Aggressive strategy — tolerates more consecutive drops before recovery.
    public static let aggressive = FrameDroppingStrategy(
        maxConsecutiveNonKeyframeDrops: 60,
        requestKeyframeAfterMaxDrops: true
    )

    /// Conservative strategy — recovers quickly with fewer consecutive drops.
    public static let conservative = FrameDroppingStrategy(
        maxConsecutiveNonKeyframeDrops: 10,
        requestKeyframeAfterMaxDrops: true
    )

    /// Returns whether a frame of the given priority should be dropped given
    /// the current consecutive drop count and congestion level.
    ///
    /// This is a pure function with no side effects.
    ///
    /// - Parameters:
    ///   - priority: The frame's priority level.
    ///   - consecutiveDropCount: Number of consecutive frames already dropped.
    ///   - congestionLevel: Congestion severity from 0.0 (none) to 1.0 (severe).
    /// - Returns: `true` if the frame should be dropped.
    public func shouldDrop(
        priority: FramePriority,
        consecutiveDropCount: Int,
        congestionLevel: Double
    ) -> Bool {
        switch priority {
        case .iFrame:
            return false
        case .bFrame:
            if consecutiveDropCount >= maxConsecutiveNonKeyframeDrops {
                return false
            }
            return congestionLevel >= 0.3
        case .pFrame:
            if consecutiveDropCount >= maxConsecutiveNonKeyframeDrops {
                return false
            }
            return congestionLevel >= 0.6
        }
    }

    /// Returns whether a keyframe request should be issued given the current
    /// consecutive drop count.
    ///
    /// - Parameter consecutiveDropCount: Number of consecutive frames already dropped.
    /// - Returns: `true` if a keyframe should be requested.
    public func shouldRequestKeyframe(consecutiveDropCount: Int) -> Bool {
        guard requestKeyframeAfterMaxDrops else { return false }
        return consecutiveDropCount >= maxConsecutiveNonKeyframeDrops
    }
}
