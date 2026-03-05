// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF0 Showcase")
struct AMF0ShowcaseTests {

    @Test("Connect command roundtrip")
    func connectCommandRoundtrip() throws {
        let props = ConnectProperties(
            app: "live",
            flashVer: "FMLE/3.0 (compatible; FMSc/1.0)",
            tcUrl: "rtmp://host/live",
            type: "nonprivate",
            fpad: false,
            capabilities: 15,
            audioCodecs: 0x0FFF,
            videoCodecs: 0x00FF,
            videoFunction: 1,
            objectEncoding: 0
        )
        let cmd = RTMPCommand.connect(transactionID: 1, properties: props)
        let encoded = cmd.encode()
        let decoded = try RTMPCommand.decode(from: encoded)

        if case .connect(let txnID, let decodedProps) = decoded {
            #expect(txnID == 1)
            #expect(decodedProps.app == "live")
            #expect(decodedProps.flashVer == "FMLE/3.0 (compatible; FMSc/1.0)")
            #expect(decodedProps.tcUrl == "rtmp://host/live")
            #expect(decodedProps.type == "nonprivate")
            #expect(decodedProps.fpad == false)
            #expect(decodedProps.capabilities == 15)
            #expect(decodedProps.audioCodecs == 0x0FFF)
            #expect(decodedProps.videoCodecs == 0x00FF)
            #expect(decodedProps.videoFunction == 1)
            #expect(decodedProps.objectEncoding == 0)
        } else {
            Issue.record("Expected .connect command")
        }
    }

    @Test("onMetaData with all StreamMetadata fields")
    func onMetaDataRoundtrip() throws {
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        meta.videoDataRate = 6000
        meta.frameRate = 30
        meta.videoCodecID = 7
        meta.audioDataRate = 160
        meta.audioSampleRate = 44100
        meta.audioSampleSize = 16
        meta.isStereo = true
        meta.audioCodecID = 10
        meta.encoder = "swift-rtmp-kit/0.2.0"

        let msg = RTMPDataMessage.setDataFrame(metadata: meta)
        let encoded = msg.encode()
        let decoded = try RTMPDataMessage.decode(from: encoded)

        if case .setDataFrame(let decodedMeta) = decoded {
            #expect(decodedMeta.width == 1920)
            #expect(decodedMeta.height == 1080)
            #expect(decodedMeta.videoDataRate == 6000)
            #expect(decodedMeta.frameRate == 30)
            #expect(decodedMeta.videoCodecID == 7)
            #expect(decodedMeta.audioDataRate == 160)
            #expect(decodedMeta.audioSampleRate == 44100)
            #expect(decodedMeta.audioSampleSize == 16)
            #expect(decodedMeta.isStereo == true)
            #expect(decodedMeta.audioCodecID == 10)
            #expect(decodedMeta.encoder == "swift-rtmp-kit/0.2.0")
        } else {
            Issue.record("Expected .setDataFrame")
        }
    }

    @Test("Complex nested objects")
    func complexNestedObjects() {
        let value: AMF0Value = .object([
            ("name", .string("test")),
            (
                "details",
                .ecmaArray([
                    ("tags", .strictArray([.string("a"), .string("b")])),
                    (
                        "metadata",
                        .object([
                            ("depth", .number(3))
                        ])
                    )
                ])
            )
        ])

        var encoder = AMF0Encoder()
        let bytes = encoder.encode(value)
        var decoder = AMF0Decoder()
        let decoded = try? decoder.decode(from: bytes)

        #expect(decoded != nil)
        if let pairs = decoded?.objectProperties {
            #expect(pairs[0].0 == "name")
            #expect(pairs[0].1.stringValue == "test")
            if let ecma = pairs[1].1.ecmaArrayEntries {
                #expect(ecma[0].0 == "tags")
                #expect(ecma[0].1.arrayElements?.count == 2)
            }
        }
    }

    @Test("Object reference encoding")
    func objectReferenceEncoding() throws {
        let ref: AMF0Value = .reference(0)
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(ref)
        // Reference marker (0x07) + uint16 index
        #expect(bytes[0] == AMF0Value.Marker.reference)
        #expect(bytes.count == 3)
    }

    @Test("fourCcList encoding for Enhanced RTMP")
    func fourCcListEncoding() throws {
        let codecs: [FourCC] = [.hevc, .av1, .vp9, .opus, .flac]
        let amfValue = EnhancedRTMP.fourCcListAMF0(codecs: codecs)

        var encoder = AMF0Encoder()
        let bytes = encoder.encode(amfValue)
        var decoder = AMF0Decoder()
        let decoded = try decoder.decode(from: bytes)

        let elements = decoded.arrayElements
        #expect(elements != nil)
        #expect(elements?.count == 5)
        #expect(elements?[0].stringValue == "hvc1")
        #expect(elements?[1].stringValue == "av01")
        #expect(elements?[2].stringValue == "vp09")
        #expect(elements?[3].stringValue == "Opus")
        #expect(elements?[4].stringValue == "fLaC")
    }

    @Test("AMF0 deeply nested objects up to depth 32")
    func deeplyNestedObjects() throws {
        // Build object nested 30 levels deep (well within limit of 32)
        var value: AMF0Value = .string("leaf")
        for i in (0..<30).reversed() {
            value = .object([("level\(i)", value)])
        }

        var encoder = AMF0Encoder()
        let bytes = encoder.encode(value)
        var decoder = AMF0Decoder()
        let decoded = try decoder.decode(from: bytes)

        // Verify root is an object
        #expect(decoded.objectProperties != nil)
        #expect(decoded.objectProperties?[0].0 == "level0")
    }

    @Test("AMF0 all 14 value types roundtrip")
    func allValueTypesRoundtrip() throws {
        let values: [AMF0Value] = [
            .number(42.5),
            .boolean(true),
            .string("hello"),
            .object([("key", .number(1))]),
            .null,
            .undefined,
            .reference(0),
            .ecmaArray([("k", .string("v"))]),
            .strictArray([.number(1), .number(2)]),
            .date(1_609_459_200_000, timeZoneOffset: 0),
            .longString(String(repeating: "x", count: 100)),
            .unsupported,
            .xmlDocument("<root/>"),
            .typedObject(className: "MyClass", properties: [("prop", .boolean(false))])
        ]

        var encoder = AMF0Encoder()
        let bytes = encoder.encode(values)
        var decoder = AMF0Decoder()
        let decoded = try decoder.decodeAll(from: bytes)

        #expect(decoded.count == 14)
        #expect(decoded[0].numberValue == 42.5)
        #expect(decoded[1].booleanValue == true)
        #expect(decoded[2].stringValue == "hello")
        #expect(decoded[3].objectProperties != nil)
        #expect(decoded[4].isNull)
        #expect(decoded[5].isUndefined)
        // decoded[6] is reference — may resolve or remain as marker
        #expect(decoded[7].ecmaArrayEntries != nil)
        #expect(decoded[8].arrayElements?.count == 2)
        if case .date(let ms, _) = decoded[9] {
            #expect(ms == 1_609_459_200_000)
        }
        #expect(decoded[10].stringValue == String(repeating: "x", count: 100))
        if case .unsupported = decoded[11] {
        } else {
            Issue.record("Expected .unsupported")
        }
        if case .xmlDocument(let xml) = decoded[12] {
            #expect(xml == "<root/>")
        }
        if case .typedObject(let className, let props) = decoded[13] {
            #expect(className == "MyClass")
            #expect(props[0].0 == "prop")
        }
    }

    @Test("Large ECMAArray with 1000 entries")
    func largeECMAArray() throws {
        var entries: [(String, AMF0Value)] = []
        for i in 0..<1000 {
            entries.append(("key\(i)", .number(Double(i))))
        }
        let value: AMF0Value = .ecmaArray(entries)

        var encoder = AMF0Encoder()
        let bytes = encoder.encode(value)
        var decoder = AMF0Decoder()
        let decoded = try decoder.decode(from: bytes)

        let decodedEntries = decoded.ecmaArrayEntries
        #expect(decodedEntries?.count == 1000)
        #expect(decodedEntries?[0].0 == "key0")
        #expect(decodedEntries?[0].1.numberValue == 0)
        #expect(decodedEntries?[999].0 == "key999")
        #expect(decodedEntries?[999].1.numberValue == 999)
    }

    @Test("String auto-selection: short vs long")
    func stringAutoSelection() {
        var encoder = AMF0Encoder()

        // Short string → type 0x02
        let shortBytes = encoder.encode(.string("hello"))
        #expect(shortBytes[0] == AMF0Value.Marker.string)

        encoder.reset()

        // Long string (≥65536 bytes) → type 0x0C
        let longStr = String(repeating: "a", count: 65_536)
        let longBytes = encoder.encode(.string(longStr))
        #expect(longBytes[0] == AMF0Value.Marker.longString)
    }

    @Test("Unicode strings roundtrip")
    func unicodeStringsRoundtrip() throws {
        let strings = ["🎙️🎬", "直播", "بث مباشر", "ライブ配信"]
        for str in strings {
            var encoder = AMF0Encoder()
            let bytes = encoder.encode(.string(str))
            var decoder = AMF0Decoder()
            let decoded = try decoder.decode(from: bytes)
            #expect(decoded.stringValue == str)
        }
    }
}
