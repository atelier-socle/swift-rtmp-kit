// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF0 Roundtrip — Primitives")
struct AMF0RoundtripPrimitiveTests {

    /// Helper: encode then decode a single value.
    private func roundtrip(_ value: AMF0Value) throws -> AMF0Value {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(value)
        var decoder = AMF0Decoder()
        return try decoder.decode(from: bytes)
    }

    // MARK: - Number

    @Test("Roundtrip number 0.0")
    func roundtripNumberZero() throws {
        #expect(try roundtrip(.number(0.0)) == .number(0.0))
    }

    @Test("Roundtrip number 1.0")
    func roundtripNumberOne() throws {
        #expect(try roundtrip(.number(1.0)) == .number(1.0))
    }

    @Test("Roundtrip number -1.0")
    func roundtripNumberNegOne() throws {
        #expect(try roundtrip(.number(-1.0)) == .number(-1.0))
    }

    @Test("Roundtrip number Pi")
    func roundtripNumberPi() throws {
        #expect(try roundtrip(.number(.pi)) == .number(.pi))
    }

    @Test("Roundtrip number greatest finite magnitude")
    func roundtripNumberMax() throws {
        #expect(try roundtrip(.number(.greatestFiniteMagnitude)) == .number(.greatestFiniteMagnitude))
    }

    @Test("Roundtrip number smallest nonzero magnitude")
    func roundtripNumberSmallest() throws {
        #expect(
            try roundtrip(.number(Double.leastNonzeroMagnitude))
                == .number(Double.leastNonzeroMagnitude))
    }

    @Test("Roundtrip NaN preserves bit pattern")
    func roundtripNaN() throws {
        let result = try roundtrip(.number(.nan))
        if case let .number(v) = result {
            #expect(v.isNaN)
        } else {
            Issue.record("Expected number")
        }
    }

    @Test("Roundtrip +Infinity")
    func roundtripPosInfinity() throws {
        #expect(try roundtrip(.number(.infinity)) == .number(.infinity))
    }

    @Test("Roundtrip -Infinity")
    func roundtripNegInfinity() throws {
        #expect(try roundtrip(.number(-.infinity)) == .number(-.infinity))
    }

    // MARK: - Boolean

    @Test("Roundtrip boolean true")
    func roundtripBoolTrue() throws {
        #expect(try roundtrip(.boolean(true)) == .boolean(true))
    }

    @Test("Roundtrip boolean false")
    func roundtripBoolFalse() throws {
        #expect(try roundtrip(.boolean(false)) == .boolean(false))
    }

    // MARK: - String

    @Test("Roundtrip empty string")
    func roundtripEmptyString() throws {
        #expect(try roundtrip(.string("")) == .string(""))
    }

    @Test("Roundtrip short string")
    func roundtripShortString() throws {
        #expect(try roundtrip(.string("hello")) == .string("hello"))
    }

    @Test("Roundtrip Unicode string with emoji")
    func roundtripUnicodeString() throws {
        #expect(try roundtrip(.string("\u{1F600}\u{1F601}")) == .string("\u{1F600}\u{1F601}"))
    }

    @Test("Roundtrip string at boundary (65535 bytes)")
    func roundtripStringBoundary() throws {
        let str = String(repeating: "A", count: 65535)
        #expect(try roundtrip(.string(str)) == .string(str))
    }

    @Test("Roundtrip auto long string (65536 bytes)")
    func roundtripAutoLongString() throws {
        let str = String(repeating: "B", count: 65536)
        let result = try roundtrip(.string(str))
        // Auto-encoded as longString, decoded as longString
        #expect(result == .longString(str))
    }

    // MARK: - Object

    @Test("Roundtrip empty object")
    func roundtripEmptyObject() throws {
        #expect(try roundtrip(.object([])) == .object([]))
    }

    @Test("Roundtrip object with properties")
    func roundtripObjectWithProps() throws {
        let obj = AMF0Value.object([
            ("name", .string("test")),
            ("value", .number(42.0)),
            ("active", .boolean(true))
        ])
        #expect(try roundtrip(obj) == obj)
    }

    @Test("Roundtrip nested object")
    func roundtripNestedObject() throws {
        let inner = AMF0Value.object([("deep", .string("value"))])
        let outer = AMF0Value.object([("inner", inner), ("top", .null)])
        #expect(try roundtrip(outer) == outer)
    }

    @Test("Roundtrip object with 100 properties")
    func roundtripLargeObject() throws {
        var pairs: [(String, AMF0Value)] = []
        for i in 0..<100 {
            pairs.append(("key\(i)", .number(Double(i))))
        }
        let obj = AMF0Value.object(pairs)
        #expect(try roundtrip(obj) == obj)
    }

    // MARK: - Null / Undefined / Unsupported

    @Test("Roundtrip null")
    func roundtripNull() throws {
        #expect(try roundtrip(.null) == .null)
    }

    @Test("Roundtrip undefined")
    func roundtripUndefined() throws {
        #expect(try roundtrip(.undefined) == .undefined)
    }

    @Test("Roundtrip unsupported")
    func roundtripUnsupported() throws {
        #expect(try roundtrip(.unsupported) == .unsupported)
    }

    // MARK: - ECMAArray

    @Test("Roundtrip empty ECMA array")
    func roundtripEmptyECMAArray() throws {
        #expect(try roundtrip(.ecmaArray([])) == .ecmaArray([]))
    }

    @Test("Roundtrip ECMA array preserves order")
    func roundtripECMAArrayOrder() throws {
        let arr = AMF0Value.ecmaArray([
            ("z", .number(3.0)),
            ("a", .number(1.0)),
            ("m", .number(2.0))
        ])
        let result = try roundtrip(arr)
        if case let .ecmaArray(pairs) = result {
            #expect(pairs[0].0 == "z")
            #expect(pairs[1].0 == "a")
            #expect(pairs[2].0 == "m")
        } else {
            Issue.record("Expected ecmaArray")
        }
    }

    // MARK: - Strict Array

    @Test("Roundtrip empty strict array")
    func roundtripEmptyStrictArray() throws {
        #expect(try roundtrip(.strictArray([])) == .strictArray([]))
    }

    @Test("Roundtrip strict array with mixed types")
    func roundtripStrictArrayMixed() throws {
        let arr = AMF0Value.strictArray([
            .number(1.0), .boolean(false), .string("x"), .null
        ])
        #expect(try roundtrip(arr) == arr)
    }

    @Test("Roundtrip large strict array (1000 elements)")
    func roundtripLargeStrictArray() throws {
        let values = (0..<1000).map { AMF0Value.number(Double($0)) }
        let arr = AMF0Value.strictArray(values)
        #expect(try roundtrip(arr) == arr)
    }

    // MARK: - Date

    @Test("Roundtrip date zero")
    func roundtripDateZero() throws {
        #expect(try roundtrip(.date(0.0, timeZoneOffset: 0)) == .date(0.0, timeZoneOffset: 0))
    }

    @Test("Roundtrip date with specific timestamp")
    func roundtripDateSpecific() throws {
        let d = AMF0Value.date(1_609_459_200_000.0, timeZoneOffset: 0)
        #expect(try roundtrip(d) == d)
    }

    @Test("Roundtrip date with negative timestamp (before epoch)")
    func roundtripDateNegative() throws {
        let d = AMF0Value.date(-86_400_000.0, timeZoneOffset: 0)
        #expect(try roundtrip(d) == d)
    }

    @Test("Roundtrip date with large timezone offset")
    func roundtripDateLargeTZ() throws {
        let d = AMF0Value.date(0.0, timeZoneOffset: 720)  // UTC+12
        #expect(try roundtrip(d) == d)
    }

    @Test("Roundtrip date with negative timezone offset")
    func roundtripDateNegTZ() throws {
        let d = AMF0Value.date(0.0, timeZoneOffset: -300)  // UTC-5
        #expect(try roundtrip(d) == d)
    }

    // MARK: - LongString

    @Test("Roundtrip long string")
    func roundtripLongString() throws {
        let str = String(repeating: "X", count: 100_000)
        #expect(try roundtrip(.longString(str)) == .longString(str))
    }

    // MARK: - XMLDocument

    @Test("Roundtrip XML document")
    func roundtripXMLDocument() throws {
        let xml = "<root><child attr=\"value\">text</child></root>"
        #expect(try roundtrip(.xmlDocument(xml)) == .xmlDocument(xml))
    }

    // MARK: - TypedObject

    @Test("Roundtrip typed object")
    func roundtripTypedObject() throws {
        let obj = AMF0Value.typedObject(
            className: "MyClass",
            properties: [
                ("id", .number(42.0)),
                ("name", .string("test"))
            ])
        #expect(try roundtrip(obj) == obj)
    }

    @Test("Roundtrip typed object with empty class name")
    func roundtripTypedObjectEmptyClass() throws {
        let obj = AMF0Value.typedObject(className: "", properties: [("x", .null)])
        #expect(try roundtrip(obj) == obj)
    }
}

@Suite("AMF0 Roundtrip — Composite")
struct AMF0RoundtripCompositeTests {

    /// Helper: encode then decode a single value.
    private func roundtrip(_ value: AMF0Value) throws -> AMF0Value {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(value)
        var decoder = AMF0Decoder()
        return try decoder.decode(from: bytes)
    }

    /// Helper: encode then decode multiple values.
    private func roundtripMultiple(_ values: [AMF0Value]) throws -> [AMF0Value] {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(values)
        var decoder = AMF0Decoder()
        return try decoder.decodeAll(from: bytes)
    }

    // MARK: - Multiple Values

    @Test("Roundtrip multiple mixed values")
    func roundtripMultipleMixed() throws {
        let values: [AMF0Value] = [
            .string("command"),
            .number(1.0),
            .null,
            .boolean(true),
            .object([("key", .string("value"))])
        ]
        let result = try roundtripMultiple(values)
        #expect(result.count == values.count)
        for (a, b) in zip(values, result) {
            #expect(a == b)
        }
    }

    // MARK: - Complex Nested Structure

    @Test("Roundtrip 3+ levels of nesting")
    func roundtripComplexNested() throws {
        let level3 = AMF0Value.object([("deep", .number(42.0))])
        let level2 = AMF0Value.strictArray([level3, .null, .boolean(true)])
        let level1 = AMF0Value.ecmaArray([("nested", level2), ("flat", .string("hi"))])
        let root = AMF0Value.object([("data", level1)])
        #expect(try roundtrip(root) == root)
    }

    // MARK: - Real-World RTMP Messages

    @Test("Roundtrip RTMP connect command")
    func roundtripRTMPConnect() throws {
        let values: [AMF0Value] = [
            .string("connect"),
            .number(1.0),
            .object([
                ("app", .string("live")),
                ("flashVer", .string("FMLE/3.0 (compatible; FMSc/1.0)")),
                ("tcUrl", .string("rtmp://live.twitch.tv/app")),
                ("type", .string("nonprivate")),
                ("fpad", .boolean(false)),
                ("capabilities", .number(15.0)),
                ("audioCodecs", .number(0x0FFF)),
                ("videoCodecs", .number(0x00FF)),
                ("videoFunction", .number(1.0)),
                ("objectEncoding", .number(0.0))
            ])
        ]
        let result = try roundtripMultiple(values)
        #expect(result.count == 3)
        #expect(result[0] == values[0])
        #expect(result[1] == values[1])
        #expect(result[2] == values[2])
    }

    @Test("Roundtrip RTMP onMetaData")
    func roundtripRTMPOnMetadata() throws {
        let values: [AMF0Value] = [
            .string("@setDataFrame"),
            .string("onMetaData"),
            .ecmaArray([
                ("width", .number(1920)),
                ("height", .number(1080)),
                ("videodatarate", .number(4500)),
                ("framerate", .number(30)),
                ("videocodecid", .number(7)),
                ("audiodatarate", .number(128)),
                ("audiosamplerate", .number(44100)),
                ("audiosamplesize", .number(16)),
                ("stereo", .boolean(true)),
                ("audiocodecid", .number(10)),
                ("encoder", .string("swift-rtmp-kit/0.2.0"))
            ])
        ]
        let result = try roundtripMultiple(values)
        #expect(result.count == 3)
        for (a, b) in zip(values, result) {
            #expect(a == b)
        }
    }

    // MARK: - Edge Case Roundtrips

    @Test("Roundtrip empty arrays")
    func roundtripEmptyArrays() throws {
        #expect(try roundtrip(.strictArray([])) == .strictArray([]))
        #expect(try roundtrip(.ecmaArray([])) == .ecmaArray([]))
    }

    @Test("Roundtrip ECMAArray with 0 count hint but actual entries")
    func roundtripECMAArrayZeroCountHint() throws {
        // Encoder always writes correct count, so this tests the standard path
        let arr = AMF0Value.ecmaArray([("a", .number(1.0)), ("b", .number(2.0))])
        #expect(try roundtrip(arr) == arr)
    }

    @Test("Roundtrip strict array nested in object nested in ecma array")
    func roundtripDeeplyMixed() throws {
        let value = AMF0Value.ecmaArray([
            (
                "items",
                .object([
                    ("list", .strictArray([.number(1), .number(2), .number(3)])),
                    ("meta", .object([("count", .number(3))]))
                ])
            )
        ])
        #expect(try roundtrip(value) == value)
    }

    @Test("Roundtrip object with duplicate keys")
    func roundtripDuplicateKeys() throws {
        let obj = AMF0Value.object([
            ("key", .number(1.0)),
            ("key", .number(2.0))
        ])
        #expect(try roundtrip(obj) == obj)
    }

    @Test("Roundtrip date with very large positive timestamp")
    func roundtripDateLargePositive() throws {
        let d = AMF0Value.date(253_402_300_800_000.0, timeZoneOffset: 0)  // year 9999
        #expect(try roundtrip(d) == d)
    }
}
