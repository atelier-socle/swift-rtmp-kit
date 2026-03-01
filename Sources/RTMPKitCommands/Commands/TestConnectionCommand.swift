// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import RTMPKit

/// Test RTMP server connectivity.
///
/// Performs a handshake + connect + createStream sequence
/// and reports success/failure with latency measurement.
///
/// Usage:
///   rtmp-cli test-connection --url rtmps://live.twitch.tv/app --key <key>
public struct TestConnectionCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "test-connection",
        abstract:
            "Test RTMP server connectivity and measure latency"
    )

    /// RTMP server URL.
    @Option(name: .long, help: "RTMP server URL")
    public var url: String?

    /// Platform preset (alternative to --url).
    @Option(
        name: .long,
        help: "Platform preset: twitch, youtube, facebook, kick"
    )
    public var preset: String?

    /// Stream key.
    @Option(name: .long, help: "Stream key")
    public var key: String

    /// Show detailed connection info.
    @Flag(name: .long, help: "Show detailed connection info")
    public var verbose: Bool = false

    public init() {}

    public func validate() throws {
        guard url != nil || preset != nil else {
            throw ValidationError(
                "Either --url or --preset is required"
            )
        }
    }

    public mutating func run() async throws {
        let display = ProgressDisplay()
        let config = try buildConfiguration()

        display.showStatus("Connecting to \(config.url)...")

        let startTime = Date()
        let publisher = RTMPPublisher()

        do {
            try await publisher.publish(configuration: config)
            let elapsed = Date().timeIntervalSince(startTime)
            let latencyMs = Int(elapsed * 1000)

            display.showSuccess(
                "Connection successful"
            )
            print(
                "  Server:  \(config.url)"
            )
            print("  Latency: \(latencyMs)ms")

            if verbose {
                let stats = await publisher.statistics
                print(
                    "  Bytes sent:     \(stats.bytesSent)"
                )
                print(
                    "  Bytes received: \(stats.bytesReceived)"
                )
            }

            await publisher.disconnect()
        } catch {
            display.showError(error.localizedDescription)
            throw ExitCode.failure
        }
    }

    // MARK: - Private

    private func buildConfiguration() throws
        -> RTMPConfiguration
    {
        if let preset {
            switch preset.lowercased() {
            case "twitch":
                return .twitch(streamKey: key)
            case "youtube":
                return .youtube(streamKey: key)
            case "facebook":
                return .facebook(streamKey: key)
            case "kick":
                return .kick(streamKey: key)
            default:
                throw ValidationError(
                    "Unknown preset: \(preset). "
                        + "Use twitch, youtube, facebook, or kick."
                )
            }
        }
        guard let url else {
            throw ValidationError(
                "Either --url or --preset is required"
            )
        }
        return RTMPConfiguration(url: url, streamKey: key)
    }
}
