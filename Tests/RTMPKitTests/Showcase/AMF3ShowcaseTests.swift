// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF3 Showcase — Types and Encoding")
struct AMF3ShowcaseTypeTests {

    @Test("Encode a complete stream description as AMF3 object")
    func streamDescription() throws {
        let streamInfo = AMF3Value.object(
            AMF3Object(
                traits: .anonymous,
                dynamicProperties: [
                    "streamName": .string("live/myStream"),
                    "videoCodec": .string("H.264"),
                    "width": .integer(1920),
                    "height": .integer(1080),
                    "frameRate": .double(30.0),
                    "bitrate": .integer(4_000_000)
                ]
            ))
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(streamInfo)
        var decoder = AMF3Decoder()
        let (decoded, _) = try decoder.decode(from: bytes)
        #expect(decoded == streamInfo)
    }

    @Test("AMF3 integers use compact variable-length encoding")
    func compactEncoding() throws {
        var encoder = AMF3Encoder()
        let intBytes = try encoder.encode(.integer(42))
        encoder.reset()
        let doubleBytes = try encoder.encode(.double(42.0))
        #expect(intBytes.count == 2)
        #expect(doubleBytes.count == 9)
    }

    @Test("String reference table deduplicates repeated strings")
    func stringDeduplication() throws {
        var encoder = AMF3Encoder()
        let first = try encoder.encode(.string("type"))
        let second = try encoder.encode(.string("type"))
        // First encoding: marker + U29 length + "type" = 1 + 1 + 4 = 6
        // Second encoding: marker + U29 reference = 1 + 1 = 2
        #expect(first.count == 6)
        #expect(second.count == 2)
    }

    @Test("Sealed object preserves property declaration order")
    func sealedPropertyOrder() throws {
        let traits = AMF3Traits.sealed(
            className: "com.example.VideoFrame",
            properties: ["timestamp", "keyframe", "size"]
        )
        let obj = AMF3Object(
            traits: traits,
            sealedProperties: [
                "timestamp": .double(1000.0),
                "keyframe": .true,
                "size": .integer(4096)
            ]
        )
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.object(obj))
        var decoder = AMF3Decoder()
        let (decoded, _) = try decoder.decode(from: bytes)
        if case let .object(decodedObj) = decoded {
            #expect(decodedObj.traits.properties == ["timestamp", "keyframe", "size"])
        } else {
            Issue.record("Expected object")
        }
    }

    @Test("ByteArray encodes raw binary data efficiently")
    func byteArrayEfficiency() throws {
        let data: [UInt8] = Array(0..<256).map { UInt8($0 & 0xFF) }
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.byteArray(data))
        // 1 marker + 2 U29 (256 << 1 | 1 = 513 → 2 bytes) + 256 data = 259
        #expect(bytes.count == 259)
    }
}

@Suite("AMF3 Showcase — RTMP Type-17 Integration")
struct AMF3ShowcaseRTMPTests {

    @Test("ObjectEncoding.amf0 is the default")
    func defaultEncoding() {
        let config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
        #expect(config.objectEncoding == .amf0)
    }

    @Test("ObjectEncoding.amf3 can be configured")
    func amf3Encoding() {
        var config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
        config.objectEncoding = .amf3
        #expect(config.objectEncoding == .amf3)
    }

    @Test("AMF3 decoder handles all 18 type markers without crashing")
    func allMarkers() throws {
        var encoder = AMF3Encoder()
        let allTypes: [AMF3Value] = [
            .undefined, .null, .false, .true,
            .integer(1), .double(1.0), .string("s"),
            .xmlDocument("<x/>"), .date(0),
            .array(dense: [], associative: [:]),
            .object(AMF3Object(traits: .anonymous)),
            .xml("<e/>"), .byteArray([]),
            .vectorInt([], fixed: false),
            .vectorUInt([], fixed: false),
            .vectorDouble([], fixed: false),
            .vectorObject([], typeName: "", fixed: false),
            .dictionary([], weakKeys: false)
        ]
        for value in allTypes {
            encoder.reset()
            let bytes = try encoder.encode(value)
            var decoder = AMF3Decoder()
            let (decoded, _) = try decoder.decode(from: bytes)
            #expect(decoded == value)
        }
    }

    @Test("Round-trip: nested AMF3 structures")
    func nestedStructures() throws {
        let nested = AMF3Value.array(
            dense: [
                .object(
                    AMF3Object(
                        traits: .anonymous,
                        dynamicProperties: ["x": .integer(1)]
                    )),
                .object(
                    AMF3Object(
                        traits: .anonymous,
                        dynamicProperties: ["x": .integer(2)]
                    ))
            ],
            associative: ["count": .integer(2)]
        )
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(nested)
        var decoder = AMF3Decoder()
        let (decoded, _) = try decoder.decode(from: bytes)
        #expect(decoded == nested)
    }

    @Test("AMF3 and AMF0 coexist — independent encoders")
    func coexistence() throws {
        // Encode "hello" with both formats
        var amf0Encoder = AMF0Encoder()
        let amf0Bytes = amf0Encoder.encode(.string("hello"))

        var amf3Encoder = AMF3Encoder()
        let amf3Bytes = try amf3Encoder.encode(.string("hello"))

        // Different wire formats
        #expect(amf0Bytes != amf3Bytes)

        // AMF0: marker(0x02) + 2-byte length + "hello" = 8 bytes
        #expect(amf0Bytes[0] == 0x02)
        // AMF3: marker(0x06) + U29 + "hello" = 7 bytes
        #expect(amf3Bytes[0] == 0x06)

        // Each decoder handles its own format
        var amf0Decoder = AMF0Decoder()
        let amf0Value = try amf0Decoder.decode(from: amf0Bytes)
        #expect(amf0Value == .string("hello"))

        var amf3Decoder = AMF3Decoder()
        let (amf3Value, _) = try amf3Decoder.decode(from: amf3Bytes)
        #expect(amf3Value == .string("hello"))
    }
}
