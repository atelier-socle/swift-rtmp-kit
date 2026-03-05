// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import RTMPKit

/// Probe RTMP server bandwidth before streaming.
///
/// Measures available uplink bandwidth, RTT, and signal quality.
///
/// Usage:
///   rtmp-cli probe rtmp://live.twitch.tv/app
///   rtmp-cli probe rtmps://server:443/app --duration 10 --json
public struct ProbeCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "probe",
        abstract:
            "Probe RTMP server bandwidth and measure connection quality"
    )

    /// RTMP server URL to probe.
    @Argument(help: "RTMP/RTMPS server URL to probe")
    public var url: String

    /// Probe duration in seconds.
    @Option(name: .long, help: "Probe duration in seconds (default: 5)")
    public var duration: Double?

    /// Use quick preset (3 seconds).
    @Flag(name: .long, help: "Quick probe (3 seconds)")
    public var quick: Bool = false

    /// Use thorough preset (10 seconds).
    @Flag(name: .long, help: "Thorough probe (10 seconds)")
    public var thorough: Bool = false

    /// Output as JSON.
    @Flag(name: .long, help: "Output result as JSON")
    public var json: Bool = false

    /// Show recommended preset for this platform.
    @Option(
        name: .long,
        help: "Show recommended preset for platform"
    )
    public var platform: String?

    public init() {}

    public func validate() throws {
        if quick && thorough {
            throw ValidationError(
                "Cannot use both --quick and --thorough"
            )
        }
    }

    public mutating func run() async throws {
        let probeConfig = buildProbeConfig()
        let display = ProgressDisplay()

        display.showStatus("Probing \(url)...")

        let probe = BandwidthProbe(configuration: probeConfig)

        do {
            let result = try await probe.probe(url: url)

            if json {
                printJSON(result)
            } else {
                printHumanReadable(result, display: display)
            }
        } catch let error as RTMPError {
            display.showError(error.description)
            throw ExitCode.failure
        } catch {
            display.showError("\(error)")
            throw ExitCode.failure
        }
    }

    // MARK: - Private

    func buildProbeConfig() -> ProbeConfiguration {
        if quick { return .quick }
        if thorough { return .thorough }
        if let duration {
            return ProbeConfiguration(duration: duration)
        }
        return .standard
    }

    private func printHumanReadable(
        _ result: ProbeResult, display: ProgressDisplay
    ) {
        let mbps = String(
            format: "%.1f", Double(result.estimatedBandwidth) / 1_000_000
        )
        let avgRTT = String(format: "%.0f", result.averageRTT)
        let minRTT = String(format: "%.0f", result.minRTT)
        let maxRTT = String(format: "%.0f", result.maxRTT)
        let loss = String(
            format: "%.1f", result.packetLossRate * 100
        )
        let quality = String(format: "%.2f", result.signalQuality)

        display.showSuccess("Probe complete")
        print()
        print("Results:")
        print("  Bandwidth:    ~\(mbps) Mbps available")
        print("  RTT:          \(avgRTT)ms avg (\(minRTT)ms min, \(maxRTT)ms max)")
        print("  Packet loss:  \(loss)%")
        print(
            "  Signal:       \(result.qualityTier.rawValue) (\(quality))"
        )

        // Show recommended tier
        let tier = selectTierForBitrate(result.recommendedBitrate)
        print()
        print(
            "Recommended:    \(tier.name) @ "
                + "\(tier.videoBitrate / 1000) kbps video + "
                + "\(tier.audioBitrate / 1000) kbps audio"
        )

        if let platform {
            showPlatformRecommendation(result, platform: platform)
        } else {
            print()
            print(
                "Tip: Use --platform twitch "
                    + "to see platform-specific preset"
            )
        }
    }

    private func showPlatformRecommendation(
        _ result: ProbeResult, platform: String
    ) {
        guard
            let preset = StreamingPlatformRegistry.platform(
                named: platform
            )
        else {
            print()
            print("  Unknown platform: \(platform)")
            return
        }

        let config = QualityPresetSelector.select(
            for: result, platform: preset, streamKey: "<your-key>"
        )

        if let meta = config.initialMetadata {
            let w = Int(meta.width ?? 0)
            let h = Int(meta.height ?? 0)
            let vbr = (meta.videoBitrate ?? 0) / 1000
            let abr = (meta.audioBitrate ?? 0) / 1000
            print()
            print(
                "  \(preset.name): \(w)x\(h) @ \(vbr) kbps video"
                    + " + \(abr) kbps audio"
            )
        }
    }

    private func printJSON(_ result: ProbeResult) {
        let jsonStr = """
            {
              "estimatedBandwidth": \(result.estimatedBandwidth),
              "recommendedBitrate": \(result.recommendedBitrate),
              "minRTT": \(result.minRTT),
              "averageRTT": \(result.averageRTT),
              "maxRTT": \(result.maxRTT),
              "packetLossRate": \(result.packetLossRate),
              "signalQuality": \(result.signalQuality),
              "qualityTier": "\(result.qualityTier.rawValue)",
              "burstsSent": \(result.burstsSent),
              "probeDuration": \(result.probeDuration)
            }
            """
        print(jsonStr)
    }

    private func selectTierForBitrate(
        _ bitrate: Int
    ) -> QualityPresetSelector.QualityTier {
        for tier in QualityPresetSelector.qualityLadder
        where tier.totalBitrate <= bitrate {
            return tier
        }
        return QualityPresetSelector.qualityLadder[
            QualityPresetSelector.qualityLadder.count - 1
        ]
    }
}
