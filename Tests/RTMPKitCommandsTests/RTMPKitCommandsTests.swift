// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing
@testable import RTMPKitCommands

@Suite("RTMPKit CLI Commands")
struct RTMPKitCommandsCoreTests {
    @Test("Command name is rtmp-cli")
    func commandName() {
        #expect(RTMPKitCommand.configuration.commandName == "rtmp-cli")
    }

    @Test("Version matches library")
    func versionMatches() {
        #expect(RTMPKitCommand.configuration.version == "0.1.0")
    }
}
