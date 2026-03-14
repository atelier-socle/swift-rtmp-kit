// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Root command for the rtmp-cli tool.
///
/// Provides subcommands for RTMP streaming operations.
public struct RTMPKitCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "rtmp-cli",
        abstract:
            "RTMP streaming toolkit"
            + " — publish, test, and inspect RTMP connections",
        version: "0.3.0",
        subcommands: [
            PublishCommand.self,
            TestConnectionCommand.self,
            InfoCommand.self,
            ProbeCommand.self,
            RecordCommand.self,
            ServerCommand.self
        ]
    )

    public init() {}
}
