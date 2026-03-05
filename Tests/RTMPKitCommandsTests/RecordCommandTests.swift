// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKitCommands

@Suite("RecordCommand — Argument Parsing")
struct RecordCommandParsingTests {

    @Test("parse with file, --url, --key")
    func parseBasic() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "my-key"
        ])
        #expect(cmd.file == "stream.flv")
        #expect(cmd.url == "rtmp://server/app")
        #expect(cmd.key == "my-key")
    }

    @Test("--output option sets output directory")
    func outputOption() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key",
            "--output", "/tmp/recordings"
        ])
        #expect(cmd.output == "/tmp/recordings")
    }

    @Test("--format option sets format")
    func formatOption() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key",
            "--format", "video"
        ])
        #expect(cmd.format == "video")
    }

    @Test("--segment option sets segment duration")
    func segmentOption() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key",
            "--segment", "3600"
        ])
        #expect(cmd.segment == 3600)
    }

    @Test("--max-size option sets max total size")
    func maxSizeOption() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key",
            "--max-size", "1048576"
        ])
        #expect(cmd.maxSize == 1_048_576)
    }

    @Test("default optional values are nil")
    func defaults() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key"
        ])
        #expect(cmd.output == nil)
        #expect(cmd.format == nil)
        #expect(cmd.segment == nil)
        #expect(cmd.maxSize == nil)
    }

    @Test("all options together parse correctly")
    func allOptions() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key",
            "--output", "/tmp/out",
            "--format", "all",
            "--segment", "1800",
            "--max-size", "500000"
        ])
        #expect(cmd.file == "stream.flv")
        #expect(cmd.url == "rtmp://server/app")
        #expect(cmd.key == "key")
        #expect(cmd.output == "/tmp/out")
        #expect(cmd.format == "all")
        #expect(cmd.segment == 1800)
        #expect(cmd.maxSize == 500_000)
    }
}

@Suite("RecordCommand — buildRecordingConfig")
struct RecordCommandBuildConfigTests {

    @Test("default format is .flv")
    func defaultFormat() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key"
        ])
        let config = cmd.buildRecordingConfig()
        #expect(config.format == .flv)
    }

    @Test("format 'video' maps to .videoElementaryStream")
    func videoFormat() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key",
            "--format", "video"
        ])
        let config = cmd.buildRecordingConfig()
        #expect(config.format == .videoElementaryStream)
    }

    @Test("format 'audio' maps to .audioElementaryStream")
    func audioFormat() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key",
            "--format", "audio"
        ])
        let config = cmd.buildRecordingConfig()
        #expect(config.format == .audioElementaryStream)
    }

    @Test("format 'all' maps to .all")
    func allFormat() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key",
            "--format", "all"
        ])
        let config = cmd.buildRecordingConfig()
        #expect(config.format == .all)
    }

    @Test("segment and maxSize propagate to config")
    func segmentAndMaxSize() throws {
        let cmd = try RecordCommand.parse([
            "stream.flv",
            "--url", "rtmp://server/app",
            "--key", "key",
            "--segment", "60",
            "--max-size", "1024"
        ])
        let config = cmd.buildRecordingConfig()
        #expect(config.segmentDuration == 60)
        #expect(config.maxTotalSize == 1024)
    }
}
