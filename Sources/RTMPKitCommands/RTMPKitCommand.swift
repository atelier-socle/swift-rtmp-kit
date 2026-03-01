// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser

/// Root command for the rtmp-cli tool.
public struct RTMPKitCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "rtmp-cli",
        abstract: "CLI tool for publishing live streams to RTMP/RTMPS servers",
        version: "0.1.0",
        subcommands: []
    )

    public init() {}
}
