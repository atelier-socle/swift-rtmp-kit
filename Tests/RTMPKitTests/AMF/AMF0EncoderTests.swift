// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF0Encoder")
struct AMF0EncoderTests {

    // MARK: - Number

    @Test("Encode number 0.0")
    func encodeNumberZero() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.number(0.0))
        #expect(bytes[0] == 0x00)  // marker
        #expect(bytes.count == 9)  // marker + 8 bytes double
        // 0.0 in IEEE 754 big-endian = all zeros
        #expect(bytes[1...8] == [0, 0, 0, 0, 0, 0, 0, 0][...])
    }

    @Test("Encode number 1.0")
    func encodeNumberOne() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.number(1.0))
        #expect(bytes[0] == 0x00)
        // 1.0 = 0x3FF0000000000000 BE
        #expect(bytes[1] == 0x3F)
        #expect(bytes[2] == 0xF0)
        #expect(bytes[3...8] == [0, 0, 0, 0, 0, 0][...])
    }

    @Test("Encode number -1.0")
    func encodeNumberNegOne() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.number(-1.0))
        #expect(bytes[0] == 0x00)
        // -1.0 = 0xBFF0000000000000
        #expect(bytes[1] == 0xBF)
        #expect(bytes[2] == 0xF0)
    }

    @Test("Encode number special values: NaN, +Inf, -Inf")
    func encodeNumberSpecialValues() {
        var encoder = AMF0Encoder()

        let nanBytes = encoder.encode(.number(.nan))
        #expect(nanBytes.count == 9)

        let posInfBytes = encoder.encode(.number(.infinity))
        #expect(posInfBytes.count == 9)
        // +Infinity = 0x7FF0000000000000
        #expect(posInfBytes[1] == 0x7F)
        #expect(posInfBytes[2] == 0xF0)

        let negInfBytes = encoder.encode(.number(-.infinity))
        #expect(negInfBytes.count == 9)
        // -Infinity = 0xFFF0000000000000
        #expect(negInfBytes[1] == 0xFF)
        #expect(negInfBytes[2] == 0xF0)
    }

    @Test("Encode number greatest finite magnitude")
    func encodeNumberMaxFinite() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.number(Double.greatestFiniteMagnitude))
        #expect(bytes.count == 9)
    }

    // MARK: - Boolean

    @Test("Encode boolean true")
    func encodeBooleanTrue() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.boolean(true))
        #expect(bytes == [0x01, 0x01])
    }

    @Test("Encode boolean false")
    func encodeBooleanFalse() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.boolean(false))
        #expect(bytes == [0x01, 0x00])
    }

    // MARK: - String

    @Test("Encode empty string")
    func encodeEmptyString() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.string(""))
        #expect(bytes == [0x02, 0x00, 0x00])
    }

    @Test("Encode short string")
    func encodeShortString() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.string("hi"))
        #expect(bytes[0] == 0x02)  // string marker
        #expect(bytes[1] == 0x00)  // length high
        #expect(bytes[2] == 0x02)  // length low = 2
        #expect(bytes[3] == 0x68)  // 'h'
        #expect(bytes[4] == 0x69)  // 'i'
    }

    @Test("Encode string with Unicode (emoji)")
    func encodeStringUnicode() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.string("\u{1F600}"))  // grinning face
        #expect(bytes[0] == 0x02)
        // U+1F600 is 4 bytes in UTF-8: F0 9F 98 80
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x04)  // length = 4
        #expect(bytes[3] == 0xF0)
        #expect(bytes[4] == 0x9F)
        #expect(bytes[5] == 0x98)
        #expect(bytes[6] == 0x80)
    }

    @Test("Encode string with CJK characters")
    func encodeStringCJK() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.string("\u{4F60}\u{597D}"))  // nihao
        #expect(bytes[0] == 0x02)
        // Each CJK char is 3 bytes in UTF-8, total 6
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x06)
    }

    @Test("Encode auto-selects LongString for strings > 65535 UTF-8 bytes")
    func encodeAutoLongString() {
        var encoder = AMF0Encoder()
        let longStr = String(repeating: "A", count: 65536)
        let bytes = encoder.encode(.string(longStr))
        #expect(bytes[0] == 0x0C)  // LongString marker
        // uint32 BE length = 65536 = 0x00010000
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x01)
        #expect(bytes[3] == 0x00)
        #expect(bytes[4] == 0x00)
    }

    @Test("Encode string at boundary (65535 bytes) uses short string marker")
    func encodeStringAtBoundary() {
        var encoder = AMF0Encoder()
        let str = String(repeating: "B", count: 65535)
        let bytes = encoder.encode(.string(str))
        #expect(bytes[0] == 0x02)  // regular String marker
        #expect(bytes[1] == 0xFF)  // length = 0xFFFF
        #expect(bytes[2] == 0xFF)
    }

    // MARK: - Object

    @Test("Encode empty object")
    func encodeEmptyObject() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.object([]))
        // 0x03 + end marker (0x00 0x00 0x09)
        #expect(bytes == [0x03, 0x00, 0x00, 0x09])
    }

    @Test("Encode object with single property")
    func encodeObjectSingleProp() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.object([("x", .number(1.0))]))
        #expect(bytes[0] == 0x03)
        // key "x": length 0x00 0x01, then 'x' (0x78)
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x01)
        #expect(bytes[3] == 0x78)
        // value: number marker + 8 bytes
        #expect(bytes[4] == 0x00)  // number marker
    }

    @Test("Encode object preserves property order")
    func encodeObjectPropertyOrder() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(
            .object([
                ("z", .number(3.0)),
                ("a", .number(1.0)),
                ("m", .number(2.0))
            ]))
        // Find key positions - "z" should come before "a" which comes before "m"
        // After marker 0x03, first key is "z"
        #expect(bytes[1] == 0x00)  // key length high
        #expect(bytes[2] == 0x01)  // key length low
        #expect(bytes[3] == 0x7A)  // 'z'
    }

    @Test("Encode object with duplicate keys encodes both")
    func encodeObjectDuplicateKeys() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(
            .object([
                ("k", .number(1.0)),
                ("k", .number(2.0))
            ]))
        // Should contain two "k" keys
        #expect(bytes[0] == 0x03)
        // Count occurrences of key "k" pattern (0x00 0x01 0x6B)
        var count = 0
        for i in 0..<(bytes.count - 2) {
            if bytes[i] == 0x00 && bytes[i + 1] == 0x01 && bytes[i + 2] == 0x6B {
                count += 1
            }
        }
        #expect(count == 2)
    }

    // MARK: - Null / Undefined / Unsupported

    @Test("Encode null")
    func encodeNull() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.null)
        #expect(bytes == [0x05])
    }

    @Test("Encode undefined")
    func encodeUndefined() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.undefined)
        #expect(bytes == [0x06])
    }

    @Test("Encode unsupported")
    func encodeUnsupported() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.unsupported)
        #expect(bytes == [0x0D])
    }

    // MARK: - Reference

    @Test("Encode reference")
    func encodeReference() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.reference(5))
        #expect(bytes == [0x07, 0x00, 0x05])
    }

    // MARK: - ECMAArray

    @Test("Encode empty ECMA array")
    func encodeEmptyECMAArray() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.ecmaArray([]))
        // 0x08 + count (0x00000000) + end marker (0x00 0x00 0x09)
        #expect(bytes == [0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09])
    }

    @Test("Encode ECMA array with entries")
    func encodeECMAArrayWithEntries() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.ecmaArray([("key", .boolean(true))]))
        #expect(bytes[0] == 0x08)  // marker
        // count = 1 (0x00000001)
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x00)
        #expect(bytes[3] == 0x00)
        #expect(bytes[4] == 0x01)
    }

    // MARK: - Strict Array

    @Test("Encode empty strict array")
    func encodeEmptyStrictArray() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.strictArray([]))
        // 0x0A + count (0x00000000)
        #expect(bytes == [0x0A, 0x00, 0x00, 0x00, 0x00])
    }

    @Test("Encode strict array with mixed types")
    func encodeStrictArrayMixed() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.strictArray([.number(1.0), .boolean(true), .null]))
        #expect(bytes[0] == 0x0A)
        // count = 3
        #expect(bytes[4] == 0x03)
        // First element: number marker
        #expect(bytes[5] == 0x00)
    }

    // MARK: - Date

    @Test("Encode date with zero timestamp")
    func encodeDateZero() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.date(0.0, timeZoneOffset: 0))
        #expect(bytes[0] == 0x0B)  // date marker
        #expect(bytes.count == 11)  // marker + 8 double + 2 tz
        // All zeros for timestamp and tz
        for i in 1...10 {
            #expect(bytes[i] == 0x00)
        }
    }

    @Test("Encode date with specific timestamp")
    func encodeDateSpecific() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.date(1_609_459_200_000.0, timeZoneOffset: 0))
        #expect(bytes[0] == 0x0B)
        #expect(bytes.count == 11)
    }

    @Test("Encode date with non-zero timezone offset")
    func encodeDateWithTimezone() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.date(0.0, timeZoneOffset: 120))
        #expect(bytes[0] == 0x0B)
        // timezone = 120 = 0x0078
        #expect(bytes[9] == 0x00)
        #expect(bytes[10] == 0x78)
    }

    // MARK: - LongString

    @Test("Encode long string explicitly")
    func encodeLongString() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.longString("hello"))
        #expect(bytes[0] == 0x0C)  // long string marker
        // uint32 length = 5
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x00)
        #expect(bytes[3] == 0x00)
        #expect(bytes[4] == 0x05)
        #expect(bytes[5] == 0x68)  // 'h'
    }

    // MARK: - XML Document

    @Test("Encode XML document")
    func encodeXMLDocument() {
        var encoder = AMF0Encoder()
        let xml = "<root><child/></root>"
        let bytes = encoder.encode(.xmlDocument(xml))
        #expect(bytes[0] == 0x0F)  // XML marker
        let expectedLen = Array(xml.utf8).count
        let encodedLen = Int(bytes[1]) << 24 | Int(bytes[2]) << 16 | Int(bytes[3]) << 8 | Int(bytes[4])
        #expect(encodedLen == expectedLen)
    }

    // MARK: - Typed Object

    @Test("Encode typed object")
    func encodeTypedObject() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode(.typedObject(className: "Foo", properties: [("x", .number(1.0))]))
        #expect(bytes[0] == 0x10)  // typed object marker
        // class name length = 3
        #expect(bytes[1] == 0x00)
        #expect(bytes[2] == 0x03)
        // "Foo"
        #expect(bytes[3] == 0x46)
        #expect(bytes[4] == 0x6F)
        #expect(bytes[5] == 0x6F)
    }

    // MARK: - Multiple Values

    @Test("Encode multiple values sequentially")
    func encodeMultipleValues() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([.string("connect"), .number(1.0), .null])
        // string "connect": 0x02 + 2 len + 7 chars = 10
        // number 1.0: 0x00 + 8 = 9
        // null: 0x05 = 1
        #expect(bytes.count == 20)
        #expect(bytes[0] == 0x02)  // string marker
        #expect(bytes[10] == 0x00)  // number marker
        #expect(bytes[19] == 0x05)  // null marker
    }

    // MARK: - Nested Object

    @Test("Encode nested object")
    func encodeNestedObject() {
        var encoder = AMF0Encoder()
        let inner = AMF0Value.object([("a", .number(1.0))])
        let outer = AMF0Value.object([("inner", inner)])
        let bytes = encoder.encode(outer)
        #expect(bytes[0] == 0x03)  // outer object marker
        // After key "inner", should find another 0x03 marker
        // key "inner" = 0x00 0x05 + "inner" (5 bytes) = 7 bytes, starting at offset 1
        #expect(bytes[8] == 0x03)  // inner object marker
    }

    // MARK: - Reset

    @Test("Reset clears encoder state")
    func resetEncoder() {
        var encoder = AMF0Encoder()
        _ = encoder.encode(.object([("a", .number(1.0))]))
        encoder.reset()
        let bytes = encoder.encode(.null)
        #expect(bytes == [0x05])
    }
}
