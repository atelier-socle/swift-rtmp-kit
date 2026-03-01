// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import RTMPKit
import Testing

@testable import RTMPKitCommands

@Suite("TestConnectionCommand — buildConfiguration()")
struct TestConnectionBuildConfigTests {

    @Test("preset twitch returns twitch config")
    func presetTwitch() throws {
        let cmd = try TestConnectionCommand.parse([
            "--preset", "twitch",
            "--key", "live_abc"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "live_abc")
        #expect(config.url.contains("twitch"))
    }

    @Test("preset youtube returns youtube config")
    func presetYouTube() throws {
        let cmd = try TestConnectionCommand.parse([
            "--preset", "youtube",
            "--key", "yt-key"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "yt-key")
        #expect(config.url.contains("youtube"))
    }

    @Test("preset facebook returns facebook config")
    func presetFacebook() throws {
        let cmd = try TestConnectionCommand.parse([
            "--preset", "facebook",
            "--key", "fb-key"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "fb-key")
        #expect(config.url.contains("facebook"))
    }

    @Test("preset kick returns kick config")
    func presetKick() throws {
        let cmd = try TestConnectionCommand.parse([
            "--preset", "kick",
            "--key", "kick-key"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "kick-key")
    }

    @Test("url builds custom config")
    func urlConfig() throws {
        let cmd = try TestConnectionCommand.parse([
            "--url", "rtmp://myserver/live",
            "--key", "mykey"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.url == "rtmp://myserver/live")
        #expect(config.streamKey == "mykey")
    }

    @Test("unknown preset throws")
    func unknownPreset() throws {
        // Parse with a valid preset first, then override
        var cmd = try TestConnectionCommand.parse([
            "--preset", "twitch",
            "--key", "key"
        ])
        cmd.preset = "invalid"
        #expect(throws: (any Error).self) {
            _ = try cmd.buildConfiguration()
        }
    }

    @Test("no url and no preset throws")
    func noURLNoPreset() throws {
        // Parse with a preset, then clear both url and preset
        var cmd = try TestConnectionCommand.parse([
            "--preset", "twitch",
            "--key", "key"
        ])
        cmd.preset = nil
        cmd.url = nil
        #expect(throws: (any Error).self) {
            _ = try cmd.buildConfiguration()
        }
    }
}
