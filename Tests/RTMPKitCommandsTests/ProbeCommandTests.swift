// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKitCommands

@Suite("ProbeCommand — Argument Parsing")
struct ProbeCommandTests {

    @Test("url argument is parsed")
    func urlArgument() throws {
        let cmd = try ProbeCommand.parse([
            "rtmp://live.twitch.tv/app"
        ])
        #expect(cmd.url == "rtmp://live.twitch.tv/app")
    }

    @Test("--duration option parsed correctly")
    func durationOption() throws {
        let cmd = try ProbeCommand.parse([
            "rtmp://server/app", "--duration", "10"
        ])
        #expect(cmd.duration == 10.0)
    }

    @Test("--quick flag sets quick preset")
    func quickFlag() throws {
        let cmd = try ProbeCommand.parse([
            "rtmp://server/app", "--quick"
        ])
        #expect(cmd.quick == true)
        let config = cmd.buildProbeConfig()
        #expect(config.duration == 3.0)
    }

    @Test("--json flag affects output format")
    func jsonFlag() throws {
        let cmd = try ProbeCommand.parse([
            "rtmp://server/app", "--json"
        ])
        #expect(cmd.json == true)
    }

    @Test("--platform option stores platform name")
    func platformOption() throws {
        let cmd = try ProbeCommand.parse([
            "rtmp://server/app", "--platform", "twitch"
        ])
        #expect(cmd.platform == "twitch")
    }

    @Test("--thorough flag sets thorough preset")
    func thoroughFlag() throws {
        let cmd = try ProbeCommand.parse([
            "rtmp://server/app", "--thorough"
        ])
        #expect(cmd.thorough == true)
        let config = cmd.buildProbeConfig()
        #expect(config.duration == 10.0)
    }
}
