// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("StreamMetadata — Extended Fields")
struct StreamMetadataExtendedFieldTests {

    @Test("New fields default to nil / empty")
    func newFieldDefaults() {
        let meta = StreamMetadata()
        #expect(meta.videoBitrate == nil)
        #expect(meta.audioBitrate == nil)
        #expect(meta.audioChannels == nil)
        #expect(meta.duration == nil)
        #expect(meta.customFields.isEmpty)
    }

    @Test("toAMF0 includes videoBitrate")
    func toAMF0VideoBitrate() {
        var meta = StreamMetadata()
        meta.videoBitrate = 3_000_000
        guard let entries = meta.toAMF0().ecmaArrayEntries else {
            Issue.record("Expected ecmaArray")
            return
        }
        let found = entries.first { $0.0 == "videoBitrate" }
        #expect(found?.1 == .number(3_000_000))
    }

    @Test("toAMF0 includes audioBitrate")
    func toAMF0AudioBitrate() {
        var meta = StreamMetadata()
        meta.audioBitrate = 128_000
        guard let entries = meta.toAMF0().ecmaArrayEntries else {
            Issue.record("Expected ecmaArray")
            return
        }
        let found = entries.first { $0.0 == "audioBitrate" }
        #expect(found?.1 == .number(128_000))
    }

    @Test("toAMF0 includes audioChannels")
    func toAMF0AudioChannels() {
        var meta = StreamMetadata()
        meta.audioChannels = 2
        guard let entries = meta.toAMF0().ecmaArrayEntries else {
            Issue.record("Expected ecmaArray")
            return
        }
        let found = entries.first { $0.0 == "audioChannels" }
        #expect(found?.1 == .number(2))
    }

    @Test("toAMF0 includes duration")
    func toAMF0Duration() {
        var meta = StreamMetadata()
        meta.duration = 0
        guard let entries = meta.toAMF0().ecmaArrayEntries else {
            Issue.record("Expected ecmaArray")
            return
        }
        let found = entries.first { $0.0 == "duration" }
        #expect(found?.1 == .number(0))
    }

    @Test("toAMF0 includes custom fields")
    func toAMF0CustomFields() {
        var meta = StreamMetadata()
        meta.customFields["myKey"] = .string("myValue")
        guard let entries = meta.toAMF0().ecmaArrayEntries else {
            Issue.record("Expected ecmaArray")
            return
        }
        let found = entries.first { $0.0 == "myKey" }
        #expect(found?.1 == .string("myValue"))
    }

    @Test("fromAMF0 parses new fields")
    func fromAMF0NewFields() {
        let amf0 = AMF0Value.ecmaArray([
            ("videoBitrate", .number(5_000_000)),
            ("audioBitrate", .number(192_000)),
            ("audioChannels", .number(6)),
            ("duration", .number(120.5))
        ])
        let meta = StreamMetadata.fromAMF0(amf0)
        #expect(meta.videoBitrate == 5_000_000)
        #expect(meta.audioBitrate == 192_000)
        #expect(meta.audioChannels == 6)
        #expect(meta.duration == 120.5)
    }

    @Test("Roundtrip with new fields")
    func roundtripNewFields() {
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        meta.videoBitrate = 4_500_000
        meta.audioBitrate = 128_000
        meta.audioChannels = 2
        meta.duration = 0
        let roundtripped = StreamMetadata.fromAMF0(meta.toAMF0())
        #expect(roundtripped == meta)
    }

    @Test("toAMF0Object returns same as toAMF0")
    func toAMF0ObjectAlias() {
        var meta = StreamMetadata()
        meta.width = 1280
        meta.videoBitrate = 2_500_000
        #expect(meta.toAMF0Object() == meta.toAMF0())
    }
}

@Suite("StreamMetadata — Factory Methods")
struct StreamMetadataFactoryTests {

    @Test("h264AAC sets correct codec IDs")
    func h264AACCodecs() {
        let meta = StreamMetadata.h264AAC(
            width: 1920, height: 1080, frameRate: 30,
            videoBitrate: 3_000_000, audioBitrate: 128_000
        )
        #expect(meta.videoCodecID == 7.0)
        #expect(meta.audioCodecID == 10.0)
    }

    @Test("h264AAC sets dimensions and frame rate")
    func h264AACDimensions() {
        let meta = StreamMetadata.h264AAC(
            width: 1280, height: 720, frameRate: 60,
            videoBitrate: 2_500_000, audioBitrate: 96_000
        )
        #expect(meta.width == 1280)
        #expect(meta.height == 720)
        #expect(meta.frameRate == 60)
    }

    @Test("h264AAC sets bitrates and audio params")
    func h264AACBitrates() {
        let meta = StreamMetadata.h264AAC(
            width: 1920, height: 1080, frameRate: 30,
            videoBitrate: 4_000_000, audioBitrate: 160_000,
            audioSampleRate: 48000, channels: 1
        )
        #expect(meta.videoBitrate == 4_000_000)
        #expect(meta.audioBitrate == 160_000)
        #expect(meta.audioSampleRate == 48000)
        #expect(meta.audioChannels == 1)
        #expect(meta.isStereo == false)
    }

    @Test("h264AAC default audio sample rate is 44100")
    func h264AACDefaultSampleRate() {
        let meta = StreamMetadata.h264AAC(
            width: 1920, height: 1080, frameRate: 30,
            videoBitrate: 3_000_000, audioBitrate: 128_000
        )
        #expect(meta.audioSampleRate == 44100)
        #expect(meta.audioChannels == 2)
        #expect(meta.isStereo == true)
    }

    @Test("hevcAAC sets correct codec IDs")
    func hevcAACCodecs() {
        let meta = StreamMetadata.hevcAAC(
            width: 3840, height: 2160, frameRate: 30,
            videoBitrate: 15_000_000, audioBitrate: 256_000
        )
        #expect(meta.videoCodecID == 12.0)
        #expect(meta.audioCodecID == 10.0)
    }

    @Test("hevcAAC default audio sample rate is 48000")
    func hevcAACDefaultSampleRate() {
        let meta = StreamMetadata.hevcAAC(
            width: 3840, height: 2160, frameRate: 60,
            videoBitrate: 20_000_000, audioBitrate: 256_000
        )
        #expect(meta.audioSampleRate == 48000)
    }

    @Test("audioOnly sets no video fields")
    func audioOnlyNoVideo() {
        let meta = StreamMetadata.audioOnly(
            codecID: 10.0, bitrate: 128_000
        )
        #expect(meta.width == nil)
        #expect(meta.height == nil)
        #expect(meta.frameRate == nil)
        #expect(meta.videoCodecID == nil)
        #expect(meta.videoBitrate == nil)
    }

    @Test("audioOnly sets audio fields")
    func audioOnlyFields() {
        let meta = StreamMetadata.audioOnly(
            codecID: 10.0, bitrate: 320_000,
            sampleRate: 48000, channels: 1
        )
        #expect(meta.audioCodecID == 10.0)
        #expect(meta.audioBitrate == 320_000)
        #expect(meta.audioSampleRate == 48000)
        #expect(meta.audioChannels == 1)
        #expect(meta.isStereo == false)
    }
}
