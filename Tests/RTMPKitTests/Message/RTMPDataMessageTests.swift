// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPDataMessage — Encoding")
struct RTMPDataMessageEncodeTests {

    @Test("setDataFrame starts with @setDataFrame and onMetaData strings")
    func encodeSetDataFrame() throws {
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        let msg = RTMPDataMessage.setDataFrame(metadata: meta)
        let bytes = msg.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values.count == 3)
        #expect(values[0] == .string("@setDataFrame"))
        #expect(values[1] == .string("onMetaData"))
    }

    @Test("setDataFrame metadata encoded as ecmaArray")
    func encodeSetDataFrameEcmaArray() throws {
        var meta = StreamMetadata()
        meta.width = 1280
        let msg = RTMPDataMessage.setDataFrame(metadata: meta)
        let bytes = msg.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values[2].ecmaArrayEntries != nil)
    }

    @Test("onMetaData starts with onMetaData string")
    func encodeOnMetaData() throws {
        let metadata = AMF0Value.ecmaArray([
            ("width", .number(1920)),
            ("height", .number(1080))
        ])
        let msg = RTMPDataMessage.onMetaData(metadata: metadata)
        let bytes = msg.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values.count == 2)
        #expect(values[0] == .string("onMetaData"))
    }

    @Test("Message type ID is 18")
    func typeID() {
        #expect(RTMPDataMessage.typeID == 18)
    }
}

@Suite("RTMPDataMessage — Decoding")
struct RTMPDataMessageDecodeTests {

    @Test("Decode setDataFrame")
    func decodeSetDataFrame() throws {
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        meta.frameRate = 30
        let original = RTMPDataMessage.setDataFrame(metadata: meta)
        let decoded = try RTMPDataMessage.decode(from: original.encode())
        if case .setDataFrame(let decodedMeta) = decoded {
            #expect(decodedMeta.width == 1920)
            #expect(decodedMeta.height == 1080)
            #expect(decodedMeta.frameRate == 30)
        } else {
            Issue.record("Expected setDataFrame")
        }
    }

    @Test("Decode onMetaData")
    func decodeOnMetaData() throws {
        let metadata = AMF0Value.ecmaArray([("width", .number(1920))])
        let original = RTMPDataMessage.onMetaData(metadata: metadata)
        let decoded = try RTMPDataMessage.decode(from: original.encode())
        if case .onMetaData(let decodedMeta) = decoded {
            #expect(decodedMeta.ecmaArrayEntries != nil)
        } else {
            Issue.record("Expected onMetaData")
        }
    }

    @Test("Decode unknown data message throws")
    func decodeUnknown() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([.string("unknownData")])
        #expect(throws: MessageError.self) {
            try RTMPDataMessage.decode(from: bytes)
        }
    }

    @Test("Decode empty bytes throws")
    func decodeEmpty() {
        #expect(throws: (any Error).self) {
            try RTMPDataMessage.decode(from: [])
        }
    }

    // MARK: - Roundtrip

    @Test("Roundtrip setDataFrame")
    func roundtripSetDataFrame() throws {
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        meta.videoDataRate = 2500
        meta.frameRate = 30
        meta.videoCodecID = 7
        meta.audioDataRate = 128
        meta.audioSampleRate = 44100
        meta.audioSampleSize = 16
        meta.isStereo = true
        meta.audioCodecID = 10
        meta.encoder = "swift-rtmp-kit"
        let original = RTMPDataMessage.setDataFrame(metadata: meta)
        let decoded = try RTMPDataMessage.decode(from: original.encode())
        #expect(decoded == original)
    }
}

@Suite("StreamMetadata")
struct StreamMetadataTests {

    @Test("Init defaults all to nil")
    func initDefaults() {
        let meta = StreamMetadata()
        #expect(meta.width == nil)
        #expect(meta.height == nil)
        #expect(meta.videoDataRate == nil)
        #expect(meta.frameRate == nil)
        #expect(meta.videoCodecID == nil)
        #expect(meta.audioDataRate == nil)
        #expect(meta.audioSampleRate == nil)
        #expect(meta.audioSampleSize == nil)
        #expect(meta.isStereo == nil)
        #expect(meta.audioCodecID == nil)
        #expect(meta.encoder == nil)
    }

    @Test("toAMF0 includes only non-nil properties")
    func toAMF0NonNil() {
        var meta = StreamMetadata()
        meta.width = 1920
        meta.encoder = "test"
        let amf0 = meta.toAMF0()
        guard let entries = amf0.ecmaArrayEntries else {
            Issue.record("Expected ecmaArray")
            return
        }
        #expect(entries.count == 2)
        #expect(entries[0].0 == "width")
        #expect(entries[1].0 == "encoder")
    }

    @Test("toAMF0 omits nil properties")
    func toAMF0OmitsNil() {
        let meta = StreamMetadata()
        let amf0 = meta.toAMF0()
        guard let entries = amf0.ecmaArrayEntries else {
            Issue.record("Expected ecmaArray")
            return
        }
        #expect(entries.isEmpty)
    }

    @Test("fromAMF0 parses all properties")
    func fromAMF0AllProps() {
        let amf0 = AMF0Value.ecmaArray([
            ("width", .number(1920)),
            ("height", .number(1080)),
            ("videodatarate", .number(2500)),
            ("framerate", .number(30)),
            ("videocodecid", .number(7)),
            ("audiodatarate", .number(128)),
            ("audiosamplerate", .number(44100)),
            ("audiosamplesize", .number(16)),
            ("stereo", .boolean(true)),
            ("audiocodecid", .number(10)),
            ("encoder", .string("test"))
        ])
        let meta = StreamMetadata.fromAMF0(amf0)
        #expect(meta.width == 1920)
        #expect(meta.height == 1080)
        #expect(meta.videoDataRate == 2500)
        #expect(meta.frameRate == 30)
        #expect(meta.videoCodecID == 7)
        #expect(meta.audioDataRate == 128)
        #expect(meta.audioSampleRate == 44100)
        #expect(meta.audioSampleSize == 16)
        #expect(meta.isStereo == true)
        #expect(meta.audioCodecID == 10)
        #expect(meta.encoder == "test")
    }

    @Test("fromAMF0 handles missing properties gracefully")
    func fromAMF0Missing() {
        let amf0 = AMF0Value.ecmaArray([
            ("width", .number(640))
        ])
        let meta = StreamMetadata.fromAMF0(amf0)
        #expect(meta.width == 640)
        #expect(meta.height == nil)
        #expect(meta.encoder == nil)
    }

    @Test("fromAMF0 handles object value")
    func fromAMF0Object() {
        let amf0 = AMF0Value.object([
            ("width", .number(1920)),
            ("height", .number(1080))
        ])
        let meta = StreamMetadata.fromAMF0(amf0)
        #expect(meta.width == 1920)
        #expect(meta.height == 1080)
    }

    @Test("fromAMF0 with null returns empty metadata")
    func fromAMF0Null() {
        let meta = StreamMetadata.fromAMF0(.null)
        #expect(meta.width == nil)
        #expect(meta.encoder == nil)
    }

    @Test("Real-world metadata: 1080p30, AAC 128kbps")
    func realWorldMetadata() throws {
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        meta.videoDataRate = 2500
        meta.frameRate = 30
        meta.videoCodecID = 7
        meta.audioDataRate = 128
        meta.audioSampleRate = 44100
        meta.audioSampleSize = 16
        meta.isStereo = true
        meta.audioCodecID = 10
        meta.encoder = "swift-rtmp-kit"
        let amf0 = meta.toAMF0()
        let parsed = StreamMetadata.fromAMF0(amf0)
        #expect(parsed == meta)
    }

    @Test("Roundtrip: toAMF0 → fromAMF0")
    func roundtrip() {
        var meta = StreamMetadata()
        meta.width = 1280
        meta.height = 720
        meta.frameRate = 60
        meta.encoder = "test-encoder"
        let roundtripped = StreamMetadata.fromAMF0(meta.toAMF0())
        #expect(roundtripped == meta)
    }
}
