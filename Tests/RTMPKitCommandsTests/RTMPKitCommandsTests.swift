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

    @Test("version is 0.1.0")
    func versionMatches() {
        #expect(
            RTMPKitCommand.configuration.version == "0.1.0"
        )
    }

    @Test("has 4 subcommands")
    func subcommandCount() {
        #expect(
            RTMPKitCommand.configuration.subcommands.count == 4
        )
    }

    @Test("abstract is non-empty")
    func abstractNonEmpty() {
        #expect(
            !RTMPKitCommand.configuration.abstract.isEmpty
        )
    }
}
