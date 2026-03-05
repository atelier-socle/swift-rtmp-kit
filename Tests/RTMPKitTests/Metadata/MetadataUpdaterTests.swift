// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

/// Helper actor for capturing bytes sent by MetadataUpdater in tests.
private actor ByteCapture {
    var last: [UInt8] = []
    var all: [[UInt8]] = []

    func store(_ bytes: [UInt8]) {
        last = bytes
        all.append(bytes)
    }
}

@Suite("MetadataUpdater")
struct MetadataUpdaterTests {

    @Test("updateStreamInfo encodes @setDataFrame + onMetaData")
    func updateStreamInfoEncoding() async throws {
        let capture = ByteCapture()
        let updater = MetadataUpdater { bytes in
            await capture.store(bytes)
        }
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        try await updater.updateStreamInfo(meta)

        let captured = await capture.last
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: captured)
        #expect(values.count == 3)
        #expect(values[0] == .string("@setDataFrame"))
        #expect(values[1] == .string("onMetaData"))
    }

    @Test("send encodes messageName + payload")
    func sendTimedMetadata() async throws {
        let capture = ByteCapture()
        let updater = MetadataUpdater { bytes in
            await capture.store(bytes)
        }
        let tm = TimedMetadata.text("hello", timestamp: 100)
        try await updater.send(tm)

        let captured = await capture.last
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: captured)
        #expect(values.count == 2)
        #expect(values[0] == .string("onTextData"))
    }

    @Test("sendText convenience")
    func sendTextConvenience() async throws {
        let capture = ByteCapture()
        let updater = MetadataUpdater { bytes in
            await capture.store(bytes)
        }
        try await updater.sendText("world", timestamp: 200)

        let captured = await capture.last
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: captured)
        #expect(values[0] == .string("onTextData"))
    }

    @Test("sendCuePoint convenience")
    func sendCuePointConvenience() async throws {
        let capture = ByteCapture()
        let updater = MetadataUpdater { bytes in
            await capture.store(bytes)
        }
        let cp = CuePoint(name: "marker", time: 5000)
        try await updater.sendCuePoint(cp)

        let captured = await capture.last
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: captured)
        #expect(values[0] == .string("onCuePoint"))
    }

    @Test("sendCaption convenience")
    func sendCaptionConvenience() async throws {
        let capture = ByteCapture()
        let updater = MetadataUpdater { bytes in
            await capture.store(bytes)
        }
        let cd = CaptionData(text: "subtitle", timestamp: 3000)
        try await updater.sendCaption(cd)

        let captured = await capture.last
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: captured)
        #expect(values[0] == .string("onCaptionInfo"))
    }

    @Test("send propagates errors from closure")
    func sendPropagatesErrors() async {
        let updater = MetadataUpdater { _ in
            throw RTMPError.notPublishing
        }
        await #expect(throws: RTMPError.self) {
            try await updater.sendText("fail", timestamp: 0)
        }
    }

    @Test("updateStreamInfo metadata roundtrips through AMF0")
    func updateStreamInfoRoundtrip() async throws {
        let capture = ByteCapture()
        let updater = MetadataUpdater { bytes in
            await capture.store(bytes)
        }
        var meta = StreamMetadata()
        meta.width = 1280
        meta.height = 720
        meta.frameRate = 60
        meta.encoder = "test"
        try await updater.updateStreamInfo(meta)

        let captured = await capture.last
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: captured)
        let parsed = StreamMetadata.fromAMF0(values[2])
        #expect(parsed.width == 1280)
        #expect(parsed.height == 720)
        #expect(parsed.frameRate == 60)
        #expect(parsed.encoder == "test")
    }

    @Test("send cuePoint payload roundtrips")
    func sendCuePointRoundtrip() async throws {
        let capture = ByteCapture()
        let updater = MetadataUpdater { bytes in
            await capture.store(bytes)
        }
        let cp = CuePoint(
            name: "scene2", time: 12000, type: .event,
            parameters: ["color": .string("red")]
        )
        try await updater.send(.cuePoint(cp))

        let captured = await capture.last
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: captured)
        #expect(values[0] == .string("onCuePoint"))
        guard let props = values[1].objectProperties else {
            Issue.record("Expected object payload")
            return
        }
        let dict = Dictionary(props, uniquingKeysWith: { _, b in b })
        #expect(dict["name"] == .string("scene2"))
        #expect(dict["time"] == .number(12000))
        #expect(dict["type"] == .string("event"))
        #expect(dict["color"] == .string("red"))
    }
}
