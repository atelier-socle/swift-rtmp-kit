// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Reason that triggered a bitrate change recommendation from the adaptive bitrate monitor.
public enum BitrateChangeReason: Sendable, Equatable, CustomStringConvertible {

    /// Buffer saturation or send-buffer backpressure detected.
    case congestionDetected

    /// Network conditions have been stable long enough to step up.
    case bandwidthRecovered

    /// Round-trip time exceeded the configured threshold above baseline.
    case rttSpike

    /// Frame drop rate exceeded the configured threshold.
    case dropRateExceeded

    /// Caller explicitly requested a bitrate change.
    case manual

    /// Human-readable description of the change reason.
    public var description: String {
        switch self {
        case .congestionDetected:
            return "Congestion detected: buffer saturation or backpressure"
        case .bandwidthRecovered:
            return "Bandwidth recovered: stable conditions allow step-up"
        case .rttSpike:
            return "RTT spike: round-trip time exceeded threshold"
        case .dropRateExceeded:
            return "Drop rate exceeded: frame drop rate above threshold"
        case .manual:
            return "Manual: bitrate change requested by caller"
        }
    }
}
