// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKitCommands

@Suite("TestConnectionCommand — Argument Parsing")
struct TestConnectionCommandParsingTests {

    @Test("parse with --url and --key")
    func parseURLAndKey() throws {
        let cmd = try TestConnectionCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "my-key"
        ])
        #expect(cmd.url == "rtmp://server/app")
        #expect(cmd.key == "my-key")
    }

    @Test("parse with --preset and --key")
    func parsePresetAndKey() throws {
        let cmd = try TestConnectionCommand.parse([
            "--preset", "twitch",
            "--key", "live_key"
        ])
        #expect(cmd.preset == "twitch")
        #expect(cmd.key == "live_key")
    }

    @Test("--verbose flag")
    func verboseFlag() throws {
        let cmd = try TestConnectionCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key",
            "--verbose"
        ])
        #expect(cmd.verbose == true)
    }

    @Test("default values (no verbose)")
    func defaultValues() throws {
        let cmd = try TestConnectionCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key"
        ])
        #expect(cmd.verbose == false)
        #expect(cmd.preset == nil)
    }

    @Test("various preset values recognized")
    func presetValues() throws {
        for presetName in ["twitch", "youtube", "facebook", "kick"] {
            let cmd = try TestConnectionCommand.parse([
                "--preset", presetName,
                "--key", "key"
            ])
            #expect(cmd.preset == presetName)
        }
    }

    @Test("--url with RTMPS scheme")
    func rtmpsScheme() throws {
        let cmd = try TestConnectionCommand.parse([
            "--url", "rtmps://live.twitch.tv/app",
            "--key", "key"
        ])
        #expect(cmd.url == "rtmps://live.twitch.tv/app")
    }

    @Test("key is required — missing key fails")
    func missingKey() {
        #expect(throws: (any Error).self) {
            _ = try TestConnectionCommand.parse([
                "--url", "rtmp://server/app"
            ])
        }
    }
}

@Suite("TestConnectionCommand — Validation")
struct TestConnectionCommandValidationTests {

    @Test("missing --url and --preset fails validation")
    func missingURLAndPreset() {
        #expect(throws: (any Error).self) {
            _ = try TestConnectionCommand.parse([
                "--key", "key"
            ])
        }
    }

    @Test("--url passes validation")
    func urlPassesValidation() throws {
        _ = try TestConnectionCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key"
        ])
    }

    @Test("--preset passes validation")
    func presetPassesValidation() throws {
        _ = try TestConnectionCommand.parse([
            "--preset", "twitch",
            "--key", "key"
        ])
    }
}
