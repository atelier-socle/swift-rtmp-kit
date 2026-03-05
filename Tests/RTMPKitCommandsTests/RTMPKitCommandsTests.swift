// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKitCommands

@Suite("RTMPKitCommand — Root Command")
struct RTMPKitCommandsCoreTests {

    @Test("command name is rtmp-cli")
    func commandName() {
        #expect(
            RTMPKitCommand.configuration.commandName == "rtmp-cli"
        )
    }

    @Test("version is 0.2.0")
    func versionMatches() {
        #expect(
            RTMPKitCommand.configuration.version == "0.2.0"
        )
    }

    @Test("has 6 subcommands")
    func subcommandCount() {
        #expect(
            RTMPKitCommand.configuration.subcommands.count == 6
        )
    }

    @Test("abstract is non-empty")
    func abstractNonEmpty() {
        #expect(
            !RTMPKitCommand.configuration.abstract.isEmpty
        )
    }
}
