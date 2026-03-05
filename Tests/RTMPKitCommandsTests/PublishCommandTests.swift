// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKitCommands

@Suite("PublishCommand — Argument Parsing")
struct PublishCommandParsingTests {

    @Test("parse with --url, --key, --file")
    func parseURLKeyFile() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "my-key",
            "--file", "video.flv"
        ])
        #expect(cmd.url == "rtmp://server/app")
        #expect(cmd.key == ["my-key"])
        #expect(cmd.file == "video.flv")
    }

    @Test("parse with --preset twitch, --key, --file")
    func parsePresetTwitch() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "live_key",
            "--file", "video.flv"
        ])
        #expect(cmd.preset == "twitch")
        #expect(cmd.key == ["live_key"])
    }

    @Test("parse with --preset youtube")
    func parsePresetYouTube() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "youtube",
            "--key", "yt-key",
            "--file", "video.flv"
        ])
        #expect(cmd.preset == "youtube")
    }

    @Test("parse with --preset facebook")
    func parsePresetFacebook() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "facebook",
            "--key", "fb-key",
            "--file", "video.flv"
        ])
        #expect(cmd.preset == "facebook")
    }

    @Test("default chunkSize is 4096")
    func defaultChunkSize() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key",
            "--file", "video.flv"
        ])
        #expect(cmd.chunkSize == 4096)
    }

    @Test("--no-enhanced-rtmp flag sets noEnhancedRTMP")
    func noEnhancedRTMPFlag() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key",
            "--file", "video.flv",
            "--no-enhanced-rtmp"
        ])
        #expect(cmd.noEnhancedRTMP == true)
    }

    @Test("--loop flag sets loop")
    func loopFlag() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key",
            "--file", "video.flv",
            "--loop"
        ])
        #expect(cmd.loop == true)
    }

    @Test("--quiet flag sets quiet")
    func quietFlag() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key",
            "--file", "video.flv",
            "--quiet"
        ])
        #expect(cmd.quiet == true)
    }

    @Test("all options together parse correctly")
    func allOptions() throws {
        let cmd = try PublishCommand.parse([
            "--preset", "twitch",
            "--key", "key",
            "--file", "video.flv",
            "--ingest", "us-east",
            "--chunk-size", "8192",
            "--no-enhanced-rtmp",
            "--loop",
            "--quiet"
        ])
        #expect(cmd.preset == "twitch")
        #expect(cmd.ingest == "us-east")
        #expect(cmd.chunkSize == 8192)
        #expect(cmd.noEnhancedRTMP == true)
        #expect(cmd.loop == true)
        #expect(cmd.quiet == true)
    }
}

@Suite("PublishCommand — Validation")
struct PublishCommandValidationTests {

    @Test("missing both --url and --preset fails validation")
    func missingURLAndPreset() {
        #expect(throws: (any Error).self) {
            _ = try PublishCommand.parse([
                "--key", "key",
                "--file", "video.flv"
            ])
        }
    }

    @Test("both --url and --preset fails validation")
    func bothURLAndPreset() {
        #expect(throws: (any Error).self) {
            _ = try PublishCommand.parse([
                "--url", "rtmp://server/app",
                "--preset", "twitch",
                "--key", "key",
                "--file", "video.flv"
            ])
        }
    }

    @Test("--ingest without twitch fails validation")
    func ingestWithoutTwitch() {
        #expect(throws: (any Error).self) {
            _ = try PublishCommand.parse([
                "--preset", "youtube",
                "--key", "key",
                "--file", "video.flv",
                "--ingest", "us-east"
            ])
        }
    }
}
