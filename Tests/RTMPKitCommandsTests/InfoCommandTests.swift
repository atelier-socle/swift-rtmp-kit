// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKitCommands

@Suite("InfoCommand — Argument Parsing")
struct InfoCommandParsingTests {

    @Test("parse with --url")
    func parseURL() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app"
        ])
        #expect(cmd.url == "rtmp://server/app")
    }

    @Test("--key is optional")
    func keyOptional() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app"
        ])
        #expect(cmd.key == nil)
    }

    @Test("--key can be provided")
    func keyProvided() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "my-key"
        ])
        #expect(cmd.key == "my-key")
    }

    @Test("--json flag")
    func jsonFlag() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app",
            "--json"
        ])
        #expect(cmd.json == true)
    }

    @Test("default values (no json, no key)")
    func defaultValues() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app"
        ])
        #expect(cmd.json == false)
        #expect(cmd.key == nil)
    }

    @Test("various URL formats accepted")
    func urlFormats() throws {
        let urls = [
            "rtmp://server/app",
            "rtmps://live.twitch.tv/app",
            "rtmp://192.168.1.1:1935/live"
        ]
        for urlStr in urls {
            let cmd = try InfoCommand.parse([
                "--url", urlStr
            ])
            #expect(cmd.url == urlStr)
        }
    }

    @Test("all options together")
    func allOptions() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key",
            "--json"
        ])
        #expect(cmd.url == "rtmp://server/app")
        #expect(cmd.key == "key")
        #expect(cmd.json == true)
    }

    @Test("missing --url fails parsing")
    func missingURL() {
        #expect(throws: (any Error).self) {
            _ = try InfoCommand.parse([])
        }
    }
}
