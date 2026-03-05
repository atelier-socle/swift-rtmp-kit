// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import RTMPKit
import Testing

@testable import RTMPKitCommands

// MARK: - DestinationArgument Parsing

@Suite("DestinationArgument — Parsing")
struct DestinationArgumentParsingTests {

    @Test("twitch:key parses to Twitch configuration")
    func parseTwitch() {
        let arg = DestinationArgument(argument: "twitch:live_abc123")
        #expect(arg != nil)
        #expect(arg?.id == "twitch/live_abc123")
        #expect(arg?.configuration.streamKey == "live_abc123")
        #expect(arg?.configuration.url.contains("twitch") == true)
    }

    @Test("youtube:key parses to YouTube configuration")
    func parseYouTube() {
        let arg = DestinationArgument(argument: "youtube:yyyy-zzzz")
        #expect(arg != nil)
        #expect(arg?.id == "youtube/yyyy-zzzz")
        #expect(arg?.configuration.streamKey == "yyyy-zzzz")
        #expect(arg?.configuration.url.contains("youtube") == true)
    }

    @Test("facebook:key parses to Facebook configuration")
    func parseFacebook() {
        let arg = DestinationArgument(argument: "facebook:FB-xxx")
        #expect(arg != nil)
        #expect(arg?.id == "facebook/FB-xxx")
        #expect(arg?.configuration.streamKey == "FB-xxx")
        #expect(arg?.configuration.url.contains("facebook") == true)
    }

    @Test("kick:key parses to Kick configuration")
    func parseKick() {
        let arg = DestinationArgument(argument: "kick:mykey")
        #expect(arg != nil)
        #expect(arg?.id == "kick/mykey")
        #expect(arg?.configuration.streamKey == "mykey")
    }

    @Test("rtmp:// URL with key parses to custom config")
    func parseRTMPURL() {
        let arg = DestinationArgument(
            argument: "rtmp://server.example.com/app:mykey"
        )
        #expect(arg != nil)
        #expect(arg?.id == "rtmp://server.example.com/app/mykey")
        #expect(arg?.configuration.streamKey == "mykey")
        #expect(arg?.configuration.url == "rtmp://server.example.com/app")
    }

    @Test("rtmps:// URL with key parses to custom RTMPS config")
    func parseRTMPSURL() {
        let arg = DestinationArgument(
            argument: "rtmps://secure.server.com/live:securekey"
        )
        #expect(arg != nil)
        #expect(arg?.id == "rtmps://secure.server.com/live/securekey")
        #expect(arg?.configuration.streamKey == "securekey")
        #expect(arg?.configuration.url == "rtmps://secure.server.com/live")
    }

    @Test("Invalid format without colon returns nil")
    func invalidNoColon() {
        let arg = DestinationArgument(argument: "invalidformat")
        #expect(arg == nil)
    }

    @Test("Empty stream key (trailing colon) returns nil")
    func emptyStreamKey() {
        let arg = DestinationArgument(argument: "twitch:")
        #expect(arg == nil)
    }

    @Test("Unknown platform returns nil")
    func unknownPlatform() {
        let arg = DestinationArgument(argument: "tiktok:somekey")
        #expect(arg == nil)
    }

    @Test("Platform name is case insensitive")
    func caseInsensitive() {
        let arg = DestinationArgument(argument: "TWITCH:mykey")
        #expect(arg != nil)
        #expect(arg?.id == "twitch/mykey")
    }
}

// MARK: - PublishCommand --dest Integration

@Suite("PublishCommand — --dest Flag")
struct PublishCommandDestFlagTests {

    @Test("--dest parses single destination")
    func singleDest() throws {
        let cmd = try PublishCommand.parse([
            "--dest", "twitch:live_key",
            "--file", "video.flv"
        ])
        #expect(cmd.dest.count == 1)
        #expect(cmd.dest[0].id == "twitch/live_key")
    }

    @Test("--dest parses multiple destinations")
    func multipleDests() throws {
        let cmd = try PublishCommand.parse([
            "--dest", "twitch:key1",
            "--dest", "youtube:key2",
            "--file", "video.flv"
        ])
        #expect(cmd.dest.count == 2)
    }

    @Test("buildDestinations with --dest only")
    func buildDestsOnly() throws {
        let cmd = try PublishCommand.parse([
            "--dest", "twitch:live_key",
            "--dest", "youtube:yt_key",
            "--file", "video.flv"
        ])
        let destinations = try cmd.buildDestinations()
        #expect(destinations.count == 2)
        #expect(destinations[0].id == "twitch/live_key")
        #expect(destinations[1].id == "youtube/yt_key")
    }

    @Test("buildDestinations with --url/--key and --dest combines all")
    func combineURLAndDest() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "primary-key",
            "--dest", "twitch:live_key",
            "--file", "video.flv"
        ])
        let destinations = try cmd.buildDestinations()
        #expect(destinations.count == 2)
        #expect(destinations[0].id == "primary")
        #expect(destinations[1].id == "twitch/live_key")
    }

    @Test("validation fails with no --url, --preset, or --dest")
    func validationFailsEmpty() {
        #expect(throws: (any Error).self) {
            _ = try PublishCommand.parse([
                "--file", "video.flv"
            ])
        }
    }

    @Test("validation fails when --url without --key")
    func validationFailsNoKey() {
        #expect(throws: (any Error).self) {
            _ = try PublishCommand.parse([
                "--url", "rtmp://server/app",
                "--file", "video.flv"
            ])
        }
    }
}
