// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration parameters for the adaptive bitrate algorithm.
///
/// Controls how aggressively the monitor reacts to network condition changes
/// and defines the bitrate bounds within which the algorithm operates.
public struct AdaptiveBitrateConfiguration: Sendable, Equatable {

    /// Minimum bitrate floor in bits per second (e.g. 300_000).
    public var minBitrate: Int

    /// Maximum bitrate ceiling in bits per second (e.g. 6_000_000).
    public var maxBitrate: Int

    /// Multiplicative factor applied when stepping down (e.g. 0.75 = -25%).
    public var stepDown: Double

    /// Multiplicative factor applied when stepping up (e.g. 1.10 = +10%).
    public var stepUp: Double

    /// RTT increase fraction that triggers a step-down (e.g. 0.30 = +30% over baseline).
    public var downTriggerThreshold: Double

    /// Seconds of stable conditions required before stepping up.
    public var upStabilityDuration: Double

    /// Sliding window duration in seconds for bandwidth estimation.
    public var measurementWindow: Double

    /// Maximum frame drop rate fraction that triggers a step-down (e.g. 0.02 = 2%).
    public var dropRateTriggerThreshold: Double

    /// Creates a configuration with all parameters specified explicitly.
    ///
    /// - Parameters:
    ///   - minBitrate: Minimum bitrate floor in bits per second.
    ///   - maxBitrate: Maximum bitrate ceiling in bits per second.
    ///   - stepDown: Multiplicative factor for stepping down (must be < 1.0).
    ///   - stepUp: Multiplicative factor for stepping up (must be > 1.0).
    ///   - downTriggerThreshold: RTT increase fraction that triggers step-down.
    ///   - upStabilityDuration: Seconds of stability required before step-up.
    ///   - measurementWindow: Sliding window duration in seconds.
    ///   - dropRateTriggerThreshold: Frame drop rate fraction that triggers step-down.
    public init(
        minBitrate: Int,
        maxBitrate: Int,
        stepDown: Double,
        stepUp: Double,
        downTriggerThreshold: Double,
        upStabilityDuration: Double,
        measurementWindow: Double,
        dropRateTriggerThreshold: Double
    ) {
        self.minBitrate = minBitrate
        self.maxBitrate = maxBitrate
        self.stepDown = stepDown
        self.stepUp = stepUp
        self.downTriggerThreshold = downTriggerThreshold
        self.upStabilityDuration = upStabilityDuration
        self.measurementWindow = measurementWindow
        self.dropRateTriggerThreshold = dropRateTriggerThreshold
    }
}

extension AdaptiveBitrateConfiguration {

    /// Conservative preset — slow step-down, very slow step-up.
    ///
    /// Ideal for live events or podcasts where stability is paramount.
    ///
    /// - Parameters:
    ///   - min: Minimum bitrate floor in bits per second.
    ///   - max: Maximum bitrate ceiling in bits per second.
    /// - Returns: A conservative adaptive bitrate configuration.
    public static func conservative(min: Int, max: Int) -> Self {
        Self(
            minBitrate: min,
            maxBitrate: max,
            stepDown: 0.80,
            stepUp: 1.05,
            downTriggerThreshold: 0.40,
            upStabilityDuration: 20.0,
            measurementWindow: 5.0,
            dropRateTriggerThreshold: 0.03
        )
    }

    /// Responsive preset — fast step-down, moderate step-up.
    ///
    /// Ideal for gaming and live sport where quick adaptation matters.
    ///
    /// - Parameters:
    ///   - min: Minimum bitrate floor in bits per second.
    ///   - max: Maximum bitrate ceiling in bits per second.
    /// - Returns: A responsive adaptive bitrate configuration.
    public static func responsive(min: Int, max: Int) -> Self {
        Self(
            minBitrate: min,
            maxBitrate: max,
            stepDown: 0.75,
            stepUp: 1.10,
            downTriggerThreshold: 0.25,
            upStabilityDuration: 8.0,
            measurementWindow: 3.0,
            dropRateTriggerThreshold: 0.02
        )
    }

    /// Aggressive preset — immediate reaction in both directions.
    ///
    /// Ideal for casual content where fast recovery is preferred.
    ///
    /// - Parameters:
    ///   - min: Minimum bitrate floor in bits per second.
    ///   - max: Maximum bitrate ceiling in bits per second.
    /// - Returns: An aggressive adaptive bitrate configuration.
    public static func aggressive(min: Int, max: Int) -> Self {
        Self(
            minBitrate: min,
            maxBitrate: max,
            stepDown: 0.65,
            stepUp: 1.15,
            downTriggerThreshold: 0.15,
            upStabilityDuration: 4.0,
            measurementWindow: 2.0,
            dropRateTriggerThreshold: 0.01
        )
    }
}
