// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import RTMPKit
import Testing

@testable import RTMPKitCommands

@Suite("ServerCommand — Argument Parsing")
struct ServerCommandTests {

    @Test("server has start, status, stop subcommands")
    func subcommands() {
        let subs = ServerCommand.configuration.subcommands
        let names = subs.map { $0.configuration.commandName }
        #expect(names.contains("start"))
        #expect(names.contains("status"))
        #expect(names.contains("stop"))
    }

    @Test("start subcommand has --port option")
    func portOption() throws {
        let cmd = try ServerCommand.StartCommand.parse([
            "--port", "8080"
        ])
        #expect(cmd.port == 8080)
    }

    @Test("start subcommand has --allow-key repeatable option")
    func allowKeyOption() throws {
        let cmd = try ServerCommand.StartCommand.parse([
            "--allow-key", "abc", "--allow-key", "def"
        ])
        #expect(cmd.allowKey == ["abc", "def"])
    }

    @Test("start subcommand has --policy option")
    func policyOption() throws {
        let cmd = try ServerCommand.StartCommand.parse([
            "--policy", "strict"
        ])
        #expect(cmd.policy == "strict")
    }

    @Test("server added to root CLI subcommands")
    func rootSubcommands() {
        let subs = RTMPKitCommand.configuration.subcommands
        let names = subs.map { $0.configuration.commandName }
        #expect(names.contains("server"))
    }

    @Test("start default values")
    func startDefaults() throws {
        let cmd = try ServerCommand.StartCommand.parse([])
        #expect(cmd.port == 1935)
        #expect(cmd.host == "0.0.0.0")
        #expect(cmd.maxSessions == 10)
        #expect(cmd.allowKey.isEmpty)
        #expect(cmd.dvr == nil)
        #expect(cmd.relay.isEmpty)
        #expect(cmd.policy == "open")
    }

    @Test("start --host option")
    func hostOption() throws {
        let cmd = try ServerCommand.StartCommand.parse([
            "--host", "127.0.0.1"
        ])
        #expect(cmd.host == "127.0.0.1")
    }

    @Test("start --dvr option")
    func dvrOption() throws {
        let cmd = try ServerCommand.StartCommand.parse([
            "--dvr", "/tmp/recordings"
        ])
        #expect(cmd.dvr == "/tmp/recordings")
    }

    @Test("start --relay option repeatable")
    func relayOption() throws {
        let cmd = try ServerCommand.StartCommand.parse([
            "--relay", "rtmp://server1/app:key1",
            "--relay", "rtmp://server2/app:key2"
        ])
        #expect(cmd.relay.count == 2)
    }

    @Test("start buildConfiguration with allow-keys uses AllowList validator")
    func buildConfigWithAllowKeys() throws {
        let cmd = try ServerCommand.StartCommand.parse([
            "--allow-key", "test"
        ])
        let config = cmd.buildConfiguration()
        #expect(config.streamKeyValidator is AllowListStreamKeyValidator)
    }
}
