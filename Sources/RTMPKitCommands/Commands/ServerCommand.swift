// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import RTMPKit

/// Manage a local RTMP ingest server.
///
/// Usage:
///   rtmp-cli server start [--port 1935] [--host 0.0.0.0]
///   rtmp-cli server status
///   rtmp-cli server stop
public struct ServerCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "server",
        abstract: "Manage a local RTMP ingest server",
        subcommands: [
            StartCommand.self,
            StatusCommand.self,
            StopCommand.self
        ],
        defaultSubcommand: StartCommand.self
    )

    public init() {}
}

// MARK: - Start

extension ServerCommand {

    /// Start a local RTMP ingest server.
    ///
    /// Listens for incoming publisher connections and logs session events.
    public struct StartCommand: AsyncParsableCommand {

        public static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start a local RTMP ingest server"
        )

        /// Port to listen on.
        @Option(name: .long, help: "Port to listen on (default: 1935)")
        public var port: Int = 1935

        /// Host/address to bind to.
        @Option(
            name: .long,
            help: "Bind address (default: 0.0.0.0)"
        )
        public var host: String = "0.0.0.0"

        /// Maximum concurrent publisher sessions.
        @Option(
            name: .long,
            help: "Max concurrent publishers (default: 10)"
        )
        public var maxSessions: Int = 10

        /// Stream keys to allow (repeatable).
        @Option(
            name: .long,
            help: "Allow stream key (repeatable)"
        )
        public var allowKey: [String] = []

        /// Directory for auto-DVR recordings.
        @Option(
            name: .long,
            help: "Enable auto-DVR to directory"
        )
        public var dvr: String?

        /// Relay destinations (repeatable, format: rtmp://server/app:key).
        @Option(
            name: .long,
            help: "Relay to destination (repeatable, rtmp://server/app:key)"
        )
        public var relay: [String] = []

        /// Security policy preset.
        @Option(
            name: .long,
            help: "Security policy: open, standard, strict (default: open)"
        )
        public var policy: String = "open"

        public init() {}

        public mutating func run() async throws {
            let serverConfig = buildConfiguration()
            let display = ProgressDisplay()

            display.showStatus(
                "RTMP Server listening on rtmp://\(host):\(port)"
            )
            display.showStatus("Press Ctrl+C to stop.")

            let server = RTMPServer(configuration: serverConfig)
            try await server.start()

            writePIDFile(port: port)

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let source = DispatchSource.makeSignalSource(
                    signal: SIGINT, queue: .main
                )
                source.setEventHandler {
                    source.cancel()
                    continuation.resume()
                }
                source.resume()
            }

            display.showStatus("Shutting down...")
            await server.stop()
            removePIDFile()
            display.showSuccess("Server stopped.")
        }

        /// Build server configuration from CLI options.
        internal func buildConfiguration() -> RTMPServerConfiguration {
            let securityPolicy = parsePolicy()

            var validator: any StreamKeyValidator = AllowAllStreamKeyValidator()
            if !allowKey.isEmpty {
                validator = AllowListStreamKeyValidator(
                    allowedKeys: Set(allowKey)
                )
            }

            var autoDVREnabled = false
            var dvrConfig = RecordingConfiguration.default
            if let dvrDir = dvr {
                autoDVREnabled = true
                dvrConfig = RecordingConfiguration(
                    outputDirectory: dvrDir
                )
            }

            return RTMPServerConfiguration(
                port: port,
                host: host,
                maxSessions: maxSessions,
                streamKeyValidator: validator,
                autoDVR: autoDVREnabled,
                dvrConfiguration: dvrConfig,
                securityPolicy: securityPolicy
            )
        }

        private func parsePolicy() -> RTMPServerSecurityPolicy {
            switch policy.lowercased() {
            case "standard": .standard
            case "strict": .strict
            default: .open
            }
        }
    }
}

// MARK: - Status

extension ServerCommand {

    /// Check the status of a running RTMP server.
    public struct StatusCommand: AsyncParsableCommand {

        public static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Check status of a running RTMP server"
        )

        public init() {}

        public mutating func run() async throws {
            guard let info = readPIDFile() else {
                print("Server is not running.")
                return
            }
            print("RTMP Server running:")
            print("  PID:  \(info.pid)")
            print("  Port: \(info.port)")
        }
    }
}

// MARK: - Stop

extension ServerCommand {

    /// Stop a running RTMP server.
    public struct StopCommand: AsyncParsableCommand {

        public static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop a running RTMP server"
        )

        public init() {}

        public mutating func run() async throws {
            guard let info = readPIDFile() else {
                print("Server is not running.")
                return
            }
            kill(info.pid, SIGTERM)
            print("Sent SIGTERM to server (PID \(info.pid)).")
            removePIDFile()
        }
    }
}

// MARK: - PID File Helpers

/// Information stored in the server PID file.
struct ServerPIDInfo: Codable {
    /// Process identifier of the server.
    let pid: pid_t
    /// Port the server is listening on.
    let port: Int
}

private let pidFilePath = "/tmp/rtmpkit-server.pid"

func writePIDFile(port: Int) {
    let info = ServerPIDInfo(pid: getpid(), port: port)
    guard let data = try? JSONEncoder().encode(info) else { return }
    FileManager.default.createFile(
        atPath: pidFilePath, contents: data
    )
}

func readPIDFile() -> ServerPIDInfo? {
    guard let data = FileManager.default.contents(atPath: pidFilePath)
    else { return nil }
    return try? JSONDecoder().decode(ServerPIDInfo.self, from: data)
}

func removePIDFile() {
    try? FileManager.default.removeItem(atPath: pidFilePath)
}
