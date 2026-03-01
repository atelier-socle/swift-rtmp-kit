// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import RTMPKit
import Testing

@testable import RTMPKitCommands

@Suite("PublishCommand — buildConfiguration()")
struct PublishCommandBuildConfigTests {

    @Test("preset twitch returns twitch config")
    func presetTwitch() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "live_abc",
            "--file", "video.flv"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "live_abc")
        #expect(config.url.contains("twitch"))
    }

    @Test("preset youtube returns youtube config")
    func presetYouTube() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "youtube",
            "--key", "yt-key",
            "--file", "video.flv"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "yt-key")
        #expect(config.url.contains("youtube"))
    }

    @Test("preset facebook returns facebook config")
    func presetFacebook() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "facebook",
            "--key", "fb-key",
            "--file", "video.flv"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "fb-key")
        #expect(config.url.contains("facebook"))
    }

    @Test("preset kick returns kick config")
    func presetKick() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "kick",
            "--key", "kick-key",
            "--file", "video.flv"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "kick-key")
    }

    @Test("url builds custom config")
    func urlConfig() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://myserver/live",
            "--key", "mykey",
            "--file", "video.flv"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.url == "rtmp://myserver/live")
        #expect(config.streamKey == "mykey")
        #expect(config.chunkSize == 4096)
        #expect(config.enhancedRTMP == true)
    }

    @Test("url with custom chunk size")
    func urlCustomChunkSize() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://myserver/live",
            "--key", "mykey",
            "--file", "video.flv",
            "--chunk-size", "8192"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.chunkSize == 8192)
    }

    @Test("url with no-enhanced-rtmp flag")
    func urlNoEnhancedRTMP() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://myserver/live",
            "--key", "mykey",
            "--file", "video.flv",
            "--no-enhanced-rtmp"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.enhancedRTMP == false)
    }

    @Test("twitch with ingest us-east")
    func twitchIngestUsEast() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "us-east"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "key")
    }

    @Test("twitch with ingest us-west")
    func twitchIngestUsWest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "us-west"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "key")
    }

    @Test("twitch with ingest europe")
    func twitchIngestEurope() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "europe"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "key")
    }

    @Test("twitch with ingest asia")
    func twitchIngestAsia() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "asia"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "key")
    }

    @Test("twitch with ingest south-america")
    func twitchIngestSouthAmerica() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "south-america"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "key")
    }

    @Test("twitch with ingest australia")
    func twitchIngestAustralia() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "australia"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "key")
    }

    @Test("twitch with ingest auto")
    func twitchIngestAuto() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "auto"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.streamKey == "key")
    }

    @Test("unknown preset throws")
    func unknownPreset() throws {
        var cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv"
        ])
        cmd.preset = "invalid"
        #expect(throws: (any Error).self) {
            _ = try cmd.buildConfiguration()
        }
    }

    @Test("no url and no preset throws")
    func noURLNoPreset() throws {
        var cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv"
        ])
        cmd.preset = nil
        cmd.url = nil
        #expect(throws: (any Error).self) {
            _ = try cmd.buildConfiguration()
        }
    }
}

@Suite("PublishCommand — parseIngestServer()")
struct PublishCommandParseIngestServerTests {

    @Test("nil ingest returns nil")
    func nilIngest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv"
        ])
        let server = cmd.parseIngestServer()
        #expect(server == nil)
    }

    @Test("auto returns .auto")
    func autoIngest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "auto"
        ])
        let server = cmd.parseIngestServer()
        #expect(server == .auto)
    }

    @Test("us-east returns .usEast")
    func usEastIngest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "us-east"
        ])
        let server = cmd.parseIngestServer()
        #expect(server == .usEast)
    }

    @Test("us-west returns .usWest")
    func usWestIngest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "us-west"
        ])
        let server = cmd.parseIngestServer()
        #expect(server == .usWest)
    }

    @Test("europe returns .europe")
    func europeIngest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "europe"
        ])
        let server = cmd.parseIngestServer()
        #expect(server == .europe)
    }

    @Test("asia returns .asia")
    func asiaIngest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "asia"
        ])
        let server = cmd.parseIngestServer()
        #expect(server == .asia)
    }

    @Test("south-america returns .southAmerica")
    func southAmericaIngest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "south-america"
        ])
        let server = cmd.parseIngestServer()
        #expect(server == .southAmerica)
    }

    @Test("australia returns .australia")
    func australiaIngest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "australia"
        ])
        let server = cmd.parseIngestServer()
        #expect(server == .australia)
    }

    @Test("unknown ingest returns nil")
    func unknownIngest() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "mars"
        ])
        let server = cmd.parseIngestServer()
        #expect(server == nil)
    }
}
