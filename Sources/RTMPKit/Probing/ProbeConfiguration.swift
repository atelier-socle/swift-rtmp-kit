// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for a bandwidth probe session.
///
/// Controls probe duration, burst parameters, and warm-up strategy.
///
/// ## Usage
/// ```swift
/// // Use a preset
/// let config = ProbeConfiguration.quick
///
/// // Custom configuration
/// let config = ProbeConfiguration(duration: 8, burstSize: 65536)
/// ```
public struct ProbeConfiguration: Sendable, Equatable {

    /// Duration of the probe in seconds (default: 5.0).
    public var duration: Double

    /// Size of each synthetic data burst in bytes (default: 32768).
    public var burstSize: Int

    /// Interval between bursts in seconds (default: 0.1).
    public var burstInterval: Double

    /// Maximum bitrate to test, in bps (default: 20,000,000 / 20 Mbps).
    public var maxTestBitrate: Int

    /// Number of warm-up bursts to discard before measuring (default: 3).
    public var warmupBursts: Int

    /// Creates a probe configuration.
    ///
    /// - Parameters:
    ///   - duration: Probe duration in seconds.
    ///   - burstSize: Size of each data burst in bytes.
    ///   - burstInterval: Interval between bursts in seconds.
    ///   - maxTestBitrate: Maximum bitrate to test in bps.
    ///   - warmupBursts: Number of initial bursts to discard.
    public init(
        duration: Double = 5.0,
        burstSize: Int = 32_768,
        burstInterval: Double = 0.1,
        maxTestBitrate: Int = 20_000_000,
        warmupBursts: Int = 3
    ) {
        self.duration = duration
        self.burstSize = burstSize
        self.burstInterval = burstInterval
        self.maxTestBitrate = maxTestBitrate
        self.warmupBursts = max(0, warmupBursts)
    }
}

extension ProbeConfiguration {

    /// Quick probe: 3 seconds, smaller bursts. For fast pre-stream check.
    public static let quick = ProbeConfiguration(
        duration: 3.0,
        burstSize: 16_384,
        burstInterval: 0.1,
        maxTestBitrate: 20_000_000,
        warmupBursts: 2
    )

    /// Standard probe: 5 seconds. Recommended for most use cases.
    public static let standard = ProbeConfiguration()

    /// Thorough probe: 10 seconds, larger bursts. For accurate measurement.
    public static let thorough = ProbeConfiguration(
        duration: 10.0,
        burstSize: 65_536,
        burstInterval: 0.1,
        maxTestBitrate: 20_000_000,
        warmupBursts: 5
    )
}
