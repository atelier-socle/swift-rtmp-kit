// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import RTMPKit

/// Query RTMP server information and capabilities.
///
/// Connects to the server, retrieves capabilities from the connect
/// response, and displays them.
///
/// Usage:
///   rtmp-cli info --url rtmp://server/app --key <stream_key>
public struct InfoCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Query RTMP server information and capabilities"
    )

    /// RTMP server URL.
    @Option(name: .long, help: "RTMP server URL")
    public var url: String

    /// Stream key (required for most servers).
    @Option(name: .long, help: "Stream key (required for most servers)")
    public var key: String?

    /// Output as JSON.
    @Flag(name: .long, help: "Output as JSON")
    public var json: Bool = false

    public init() {}

    public mutating func run() async throws {
        let display = ProgressDisplay()
        let streamKey = key ?? ""

        display.showStatus("Connecting to \(url)...")

        let publisher = RTMPPublisher()

        do {
            try await publisher.publish(
                url: url,
                streamKey: streamKey,
                enhancedRTMP: true
            )

            let stats = await publisher.statistics
            let info = await publisher.serverInfo

            if json {
                printJSON(stats: stats, serverInfo: info)
            } else {
                printInfo(stats: stats, serverInfo: info)
            }

            await publisher.disconnect()
        } catch let error as RTMPError {
            display.showError(error.description)
            throw ExitCode.failure
        } catch {
            display.showError("\(error)")
            throw ExitCode.failure
        }
    }

    // MARK: - Private

    func printInfo(
        stats: ConnectionStatistics,
        serverInfo: ServerInfo = ServerInfo()
    ) {
        let parsed = parseURL(url)
        print(ColorOutput.bold("Server Information"))
        print("  Server:         \(parsed.host):\(parsed.port)")
        print(
            "  Protocol:       \(parsed.useTLS ? "RTMPS" : "RTMP")"
        )
        print("  App:            \(parsed.app)")
        if let version = serverInfo.version {
            print("  Server version: \(version)")
        }
        if let caps = serverInfo.capabilities {
            print("  Capabilities:   \(Int(caps))")
        }
        if serverInfo.enhancedRTMP {
            let codecs = serverInfo.negotiatedCodecs
                .map(\.stringValue).joined(separator: ", ")
            print("  Enhanced RTMP:  yes (\(codecs))")
        } else {
            print("  Enhanced RTMP:  no")
        }
        print("  Bytes sent:     \(stats.bytesSent)")
        print(
            "  Bytes received: \(stats.bytesReceived)"
        )
        if let rtt = stats.roundTripTime {
            print(
                "  Latency:        "
                    + "\(String(format: "%.0f", rtt * 1000))ms"
            )
        }
    }

    func printJSON(
        stats: ConnectionStatistics,
        serverInfo: ServerInfo = ServerInfo()
    ) {
        let parsed = parseURL(url)
        print("{")
        print("  \"host\": \"\(parsed.host)\",")
        print("  \"port\": \(parsed.port),")
        print("  \"tls\": \(parsed.useTLS),")
        print("  \"app\": \"\(parsed.app)\",")
        if let version = serverInfo.version {
            print("  \"serverVersion\": \"\(version)\",")
        }
        if let caps = serverInfo.capabilities {
            print("  \"capabilities\": \(Int(caps)),")
        }
        print("  \"enhancedRTMP\": \(serverInfo.enhancedRTMP),")
        if serverInfo.enhancedRTMP {
            let codecs = serverInfo.negotiatedCodecs
                .map { "\"\($0.stringValue)\"" }
                .joined(separator: ", ")
            print("  \"negotiatedCodecs\": [\(codecs)],")
        }
        print("  \"bytesSent\": \(stats.bytesSent),")
        print("  \"bytesReceived\": \(stats.bytesReceived)")
        print("}")
    }

    struct ParsedURL {
        let host: String
        let port: Int
        let useTLS: Bool
        let app: String
    }

    func parseURL(_ urlString: String) -> ParsedURL {
        let useTLS = urlString.hasPrefix("rtmps://")
        let defaultPort = useTLS ? 443 : 1935
        var remaining = urlString
        if remaining.hasPrefix("rtmps://") {
            remaining = String(remaining.dropFirst(8))
        } else if remaining.hasPrefix("rtmp://") {
            remaining = String(remaining.dropFirst(7))
        }
        let parts = remaining.split(separator: "/", maxSplits: 1)
        let hostPort = String(parts.first ?? "")
        let app = parts.count > 1 ? String(parts[1]) : ""
        let hostParts = hostPort.split(separator: ":")
        let host = String(hostParts.first ?? "")
        let port =
            hostParts.count > 1
            ? Int(hostParts[1]) ?? defaultPort : defaultPort
        return ParsedURL(
            host: host, port: port, useTLS: useTLS, app: app
        )
    }
}
