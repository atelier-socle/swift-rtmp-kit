// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// The result of a bandwidth probe session.
///
/// Contains measured bandwidth, latency, packet loss, and signal quality
/// along with a recommended streaming bitrate.
public struct ProbeResult: Sendable, Equatable {

    /// Estimated available uplink bandwidth in bps.
    public let estimatedBandwidth: Int

    /// Minimum observed RTT during the probe in milliseconds.
    public let minRTT: Double

    /// Average RTT during the probe in milliseconds.
    public let averageRTT: Double

    /// Maximum observed RTT during the probe in milliseconds.
    public let maxRTT: Double

    /// Packet loss rate observed during the probe (0.0–1.0).
    public let packetLossRate: Double

    /// Duration of the probe in seconds (actual, may differ from configured).
    public let probeDuration: Double

    /// Number of bursts sent during the probe.
    public let burstsSent: Int

    /// Quality of the probe signal (0.0–1.0). Higher = more reliable estimate.
    ///
    /// Computed from RTT jitter (60% weight) and loss rate (40% weight).
    public let signalQuality: Double

    /// Recommended safe streaming bitrate (80% of estimated bandwidth).
    ///
    /// This conservative factor accounts for protocol overhead and jitter.
    public var recommendedBitrate: Int {
        Int(Double(estimatedBandwidth) * 0.80)
    }

    /// Creates a probe result.
    ///
    /// - Parameters:
    ///   - estimatedBandwidth: Estimated bandwidth in bps.
    ///   - minRTT: Minimum RTT in milliseconds.
    ///   - averageRTT: Average RTT in milliseconds.
    ///   - maxRTT: Maximum RTT in milliseconds.
    ///   - packetLossRate: Packet loss rate (0.0–1.0).
    ///   - probeDuration: Actual probe duration in seconds.
    ///   - burstsSent: Number of bursts sent.
    ///   - signalQuality: Signal quality (0.0–1.0).
    public init(
        estimatedBandwidth: Int,
        minRTT: Double,
        averageRTT: Double,
        maxRTT: Double,
        packetLossRate: Double,
        probeDuration: Double,
        burstsSent: Int,
        signalQuality: Double
    ) {
        self.estimatedBandwidth = estimatedBandwidth
        self.minRTT = minRTT
        self.averageRTT = averageRTT
        self.maxRTT = maxRTT
        self.packetLossRate = packetLossRate
        self.probeDuration = probeDuration
        self.burstsSent = burstsSent
        self.signalQuality = signalQuality
    }
}

// MARK: - Quality Tier

extension ProbeResult {

    /// Quality tier classification based on signal quality.
    public enum QualityTier: String, Sendable {
        /// Signal quality >= 0.85.
        case excellent
        /// Signal quality >= 0.65.
        case good
        /// Signal quality >= 0.40.
        case fair
        /// Signal quality < 0.40.
        case poor
    }

    /// The quality tier for this probe result.
    public var qualityTier: QualityTier {
        if signalQuality >= 0.85 { return .excellent }
        if signalQuality >= 0.65 { return .good }
        if signalQuality >= 0.40 { return .fair }
        return .poor
    }
}

// MARK: - Summary

extension ProbeResult {

    /// A human-readable summary of the probe result.
    public var summary: String {
        let mbps = String(format: "%.1f", Double(estimatedBandwidth) / 1_000_000)
        let avgRTTStr = String(format: "%.0f", averageRTT)
        let qualityStr = String(format: "%.2f", signalQuality)
        return "~\(mbps) Mbps available, RTT \(avgRTTStr)ms avg, "
            + "signal quality: \(qualityTier.rawValue) (\(qualityStr))"
    }
}
