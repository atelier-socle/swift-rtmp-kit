// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

/// Helper actor for capturing bytes in showcase tests.
private actor ShowcaseCapture {
    var payloads: [[UInt8]] = []
    var names: [String] = []

    func store(_ bytes: [UInt8]) {
        payloads.append(bytes)
    }

    func storeName(_ bytes: [UInt8]) {
        var decoder = AMF0Decoder()
        if let values = try? decoder.decodeAll(from: bytes),
            let first = values.first?.stringValue
        {
            names.append(first)
        }
    }
}

@Suite("Metadata — Showcase / Integration")
struct MetadataShowcaseTests {

    // MARK: - StreamMetadata Factories → AMF0 Roundtrip

    @Test("h264AAC factory → toAMF0 → fromAMF0 roundtrip")
    func h264AACRoundtrip() {
        let meta = StreamMetadata.h264AAC(
            width: 1920, height: 1080, frameRate: 30,
            videoBitrate: 4_500_000, audioBitrate: 128_000
        )
        let roundtripped = StreamMetadata.fromAMF0(meta.toAMF0())
        #expect(roundtripped.width == 1920)
        #expect(roundtripped.height == 1080)
        #expect(roundtripped.frameRate == 30)
        #expect(roundtripped.videoCodecID == 7.0)
        #expect(roundtripped.videoBitrate == 4_500_000)
        #expect(roundtripped.audioCodecID == 10.0)
        #expect(roundtripped.audioBitrate == 128_000)
    }

    @Test("hevcAAC factory → toAMF0 → fromAMF0 roundtrip")
    func hevcAACRoundtrip() {
        let meta = StreamMetadata.hevcAAC(
            width: 3840, height: 2160, frameRate: 60,
            videoBitrate: 20_000_000, audioBitrate: 256_000
        )
        let roundtripped = StreamMetadata.fromAMF0(meta.toAMF0())
        #expect(roundtripped.videoCodecID == 12.0)
        #expect(roundtripped.videoBitrate == 20_000_000)
        #expect(roundtripped.audioSampleRate == 48000)
    }

    @Test("audioOnly factory → toAMF0 → fromAMF0 roundtrip")
    func audioOnlyRoundtrip() {
        let meta = StreamMetadata.audioOnly(
            codecID: 10.0, bitrate: 320_000,
            sampleRate: 48000, channels: 1
        )
        let roundtripped = StreamMetadata.fromAMF0(meta.toAMF0())
        #expect(roundtripped.audioCodecID == 10.0)
        #expect(roundtripped.audioBitrate == 320_000)
        #expect(roundtripped.audioChannels == 1)
        #expect(roundtripped.width == nil)
    }

    // MARK: - Custom Fields Roundtrip

    @Test("Custom fields survive AMF0 roundtrip")
    func customFieldsRoundtrip() {
        var meta = StreamMetadata()
        meta.width = 1920
        meta.customFields["copyright"] = .string("2026 Acme")
        meta.customFields["rating"] = .number(5)
        let amf0 = meta.toAMF0()
        guard let entries = amf0.ecmaArrayEntries else {
            Issue.record("Expected ecmaArray")
            return
        }
        let dict = Dictionary(entries, uniquingKeysWith: { _, b in b })
        #expect(dict["copyright"] == .string("2026 Acme"))
        #expect(dict["rating"] == .number(5))
        #expect(dict["width"] == .number(1920))
    }

    // MARK: - MetadataUpdater with Full Pipeline

    @Test("MetadataUpdater: full stream metadata pipeline")
    func fullStreamMetadataPipeline() async throws {
        let capture = ShowcaseCapture()
        let updater = MetadataUpdater { bytes in
            await capture.store(bytes)
        }

        let meta = StreamMetadata.h264AAC(
            width: 1920, height: 1080, frameRate: 30,
            videoBitrate: 4_500_000, audioBitrate: 128_000
        )
        try await updater.updateStreamInfo(meta)

        let payloads = await capture.payloads
        #expect(payloads.count == 1)
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: payloads[0])
        #expect(values[0] == .string("@setDataFrame"))
        #expect(values[1] == .string("onMetaData"))
        let parsed = StreamMetadata.fromAMF0(values[2])
        #expect(parsed.width == 1920)
        #expect(parsed.videoCodecID == 7.0)
    }

    @Test("MetadataUpdater: multiple timed metadata types")
    func multipleTimedMetadata() async throws {
        let capture = ShowcaseCapture()
        let updater = MetadataUpdater { bytes in
            await capture.storeName(bytes)
        }

        try await updater.sendText("hello", timestamp: 0)
        try await updater.sendCuePoint(CuePoint(name: "ch1", time: 1000))
        try await updater.sendCaption(CaptionData(text: "sub", timestamp: 2000))

        let names = await capture.names
        #expect(names == ["onTextData", "onCuePoint", "onCaptionInfo"])
    }

    // MARK: - RTMPConfiguration initialMetadata

    @Test("RTMPConfiguration initialMetadata defaults to nil")
    func configInitialMetadataDefault() {
        let config = RTMPConfiguration(url: "rtmp://test/app", streamKey: "key")
        #expect(config.initialMetadata == nil)
    }

    @Test("RTMPConfiguration initialMetadata can be set")
    func configInitialMetadataSet() {
        var config = RTMPConfiguration(url: "rtmp://test/app", streamKey: "key")
        config.initialMetadata = StreamMetadata.h264AAC(
            width: 1920, height: 1080, frameRate: 30,
            videoBitrate: 3_000_000, audioBitrate: 128_000
        )
        #expect(config.initialMetadata != nil)
        #expect(config.initialMetadata?.width == 1920)
    }

    // MARK: - CuePoint with parameters

    @Test("CuePoint with rich parameters encodes correctly")
    func cuePointRichParams() {
        let cp = CuePoint(
            name: "ad-break",
            time: 30000,
            type: .event,
            parameters: [
                "duration": .number(15),
                "sponsor": .string("acme"),
                "skippable": .boolean(true)
            ]
        )
        let amf0 = cp.toAMF0Object()
        guard let props = amf0.objectProperties else {
            Issue.record("Expected object")
            return
        }
        let dict = Dictionary(props, uniquingKeysWith: { _, b in b })
        #expect(dict["name"] == .string("ad-break"))
        #expect(dict["duration"] == .number(15))
        #expect(dict["sponsor"] == .string("acme"))
        #expect(dict["skippable"] == .boolean(true))
    }

    // MARK: - Caption Standards

    @Test("All caption standards encode correctly")
    func allCaptionStandards() {
        for standard in CaptionData.CaptionStandard.allCases {
            let cd = CaptionData(
                standard: standard, text: "test",
                language: "en", timestamp: 0
            )
            let amf0 = cd.toAMF0Object()
            guard let props = amf0.objectProperties else {
                Issue.record("Expected object for \(standard)")
                continue
            }
            let dict = Dictionary(props, uniquingKeysWith: { _, b in b })
            #expect(dict["standard"] == .string(standard.rawValue))
        }
    }
}
