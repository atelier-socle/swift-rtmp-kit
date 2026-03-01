// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF0Decoder — Types")
struct AMF0DecoderTypeTests {

    // MARK: - Number

    @Test("Decode number 0.0")
    func decodeNumberZero() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [0x00, 0, 0, 0, 0, 0, 0, 0, 0]
        let value = try decoder.decode(from: bytes)
        #expect(value == .number(0.0))
    }

    @Test("Decode number 1.0")
    func decodeNumberOne() throws {
        var decoder = AMF0Decoder()
        // 1.0 = 0x3FF0000000000000
        let bytes: [UInt8] = [0x00, 0x3F, 0xF0, 0, 0, 0, 0, 0, 0]
        let value = try decoder.decode(from: bytes)
        #expect(value == .number(1.0))
    }

    @Test("Decode number -1.0")
    func decodeNumberNegOne() throws {
        var decoder = AMF0Decoder()
        // -1.0 = 0xBFF0000000000000
        let bytes: [UInt8] = [0x00, 0xBF, 0xF0, 0, 0, 0, 0, 0, 0]
        let value = try decoder.decode(from: bytes)
        #expect(value == .number(-1.0))
    }

    @Test("Decode number +Infinity")
    func decodeNumberPosInf() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [0x00, 0x7F, 0xF0, 0, 0, 0, 0, 0, 0]
        let value = try decoder.decode(from: bytes)
        #expect(value == .number(.infinity))
    }

    @Test("Decode number -Infinity")
    func decodeNumberNegInf() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [0x00, 0xFF, 0xF0, 0, 0, 0, 0, 0, 0]
        let value = try decoder.decode(from: bytes)
        #expect(value == .number(-.infinity))
    }

    // MARK: - Boolean

    @Test("Decode boolean true")
    func decodeBooleanTrue() throws {
        var decoder = AMF0Decoder()
        let value = try decoder.decode(from: [0x01, 0x01])
        #expect(value == .boolean(true))
    }

    @Test("Decode boolean false")
    func decodeBooleanFalse() throws {
        var decoder = AMF0Decoder()
        let value = try decoder.decode(from: [0x01, 0x00])
        #expect(value == .boolean(false))
    }

    @Test("Decode boolean non-zero treated as true")
    func decodeBooleanNonZero() throws {
        var decoder = AMF0Decoder()
        let value = try decoder.decode(from: [0x01, 0xFF])
        #expect(value == .boolean(true))
    }

    // MARK: - String

    @Test("Decode empty string")
    func decodeEmptyString() throws {
        var decoder = AMF0Decoder()
        let value = try decoder.decode(from: [0x02, 0x00, 0x00])
        #expect(value == .string(""))
    }

    @Test("Decode short string 'hi'")
    func decodeShortString() throws {
        var decoder = AMF0Decoder()
        let value = try decoder.decode(from: [0x02, 0x00, 0x02, 0x68, 0x69])
        #expect(value == .string("hi"))
    }

    @Test("Decode Unicode string")
    func decodeUnicodeString() throws {
        var decoder = AMF0Decoder()
        // U+1F600 = F0 9F 98 80
        let bytes: [UInt8] = [0x02, 0x00, 0x04, 0xF0, 0x9F, 0x98, 0x80]
        let value = try decoder.decode(from: bytes)
        #expect(value == .string("\u{1F600}"))
    }

    // MARK: - Object

    @Test("Decode empty object")
    func decodeEmptyObject() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [0x03, 0x00, 0x00, 0x09]
        let value = try decoder.decode(from: bytes)
        #expect(value == .object([]))
    }

    @Test("Decode object with single property")
    func decodeObjectSingleProp() throws {
        var decoder = AMF0Decoder()
        // object { "x": null }
        let bytes: [UInt8] = [
            0x03,  // object
            0x00, 0x01, 0x78,  // key "x"
            0x05,  // null
            0x00, 0x00, 0x09  // end
        ]
        let value = try decoder.decode(from: bytes)
        #expect(value == .object([("x", .null)]))
    }

    @Test("Decode object preserves property order")
    func decodeObjectPreservesOrder() throws {
        var decoder = AMF0Decoder()
        // object { "z": null, "a": null }
        let bytes: [UInt8] = [
            0x03,
            0x00, 0x01, 0x7A, 0x05,  // "z": null
            0x00, 0x01, 0x61, 0x05,  // "a": null
            0x00, 0x00, 0x09
        ]
        let value = try decoder.decode(from: bytes)
        if case let .object(pairs) = value {
            #expect(pairs[0].0 == "z")
            #expect(pairs[1].0 == "a")
        } else {
            Issue.record("Expected object")
        }
    }

    @Test("Decode nested object")
    func decodeNestedObject() throws {
        var decoder = AMF0Decoder()
        // object { "inner": object { "a": null } }
        let bytes: [UInt8] = [
            0x03,  // outer object
            0x00, 0x05, 0x69, 0x6E, 0x6E, 0x65, 0x72,  // key "inner"
            0x03,  // inner object
            0x00, 0x01, 0x61,  // key "a"
            0x05,  // null
            0x00, 0x00, 0x09,  // inner end
            0x00, 0x00, 0x09  // outer end
        ]
        let value = try decoder.decode(from: bytes)
        let expected = AMF0Value.object([("inner", .object([("a", .null)]))])
        #expect(value == expected)
    }

    // MARK: - Null / Undefined / Unsupported

    @Test("Decode null")
    func decodeNull() throws {
        var decoder = AMF0Decoder()
        let value = try decoder.decode(from: [0x05])
        #expect(value == .null)
    }

    @Test("Decode undefined")
    func decodeUndefined() throws {
        var decoder = AMF0Decoder()
        let value = try decoder.decode(from: [0x06])
        #expect(value == .undefined)
    }

    @Test("Decode unsupported")
    func decodeUnsupported() throws {
        var decoder = AMF0Decoder()
        let value = try decoder.decode(from: [0x0D])
        #expect(value == .unsupported)
    }

    // MARK: - Reference

    @Test("Decode reference resolves to previously decoded object")
    func decodeReference() throws {
        var decoder = AMF0Decoder()
        // First: an object { "a": null }, then a reference to it
        let bytes: [UInt8] = [
            0x03,  // object
            0x00, 0x01, 0x61, 0x05,  // "a": null
            0x00, 0x00, 0x09,  // end
            0x07, 0x00, 0x00  // reference index 0
        ]
        let values = try decoder.decodeAll(from: bytes)
        #expect(values.count == 2)
        #expect(values[0] == values[1])
    }

    // MARK: - ECMAArray

    @Test("Decode empty ECMA array")
    func decodeEmptyECMAArray() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09]
        let value = try decoder.decode(from: bytes)
        #expect(value == .ecmaArray([]))
    }

    @Test("Decode ECMA array with entries")
    func decodeECMAArrayWithEntries() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [
            0x08,  // ecma array
            0x00, 0x00, 0x00, 0x01,  // count hint = 1
            0x00, 0x01, 0x6B,  // key "k"
            0x01, 0x01,  // boolean true
            0x00, 0x00, 0x09  // end
        ]
        let value = try decoder.decode(from: bytes)
        #expect(value == .ecmaArray([("k", .boolean(true))]))
    }

    @Test("Decode ECMA array ignores count hint")
    func decodeECMAArrayIgnoresCount() throws {
        var decoder = AMF0Decoder()
        // Count says 99 but only 1 entry before end marker
        let bytes: [UInt8] = [
            0x08,
            0x00, 0x00, 0x00, 0x63,  // count = 99 (wrong)
            0x00, 0x01, 0x61, 0x05,  // "a": null
            0x00, 0x00, 0x09
        ]
        let value = try decoder.decode(from: bytes)
        if case let .ecmaArray(pairs) = value {
            #expect(pairs.count == 1)
        } else {
            Issue.record("Expected ecmaArray")
        }
    }

    // MARK: - Strict Array

    @Test("Decode empty strict array")
    func decodeEmptyStrictArray() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [0x0A, 0x00, 0x00, 0x00, 0x00]
        let value = try decoder.decode(from: bytes)
        #expect(value == .strictArray([]))
    }

    @Test("Decode strict array with values")
    func decodeStrictArrayWithValues() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [
            0x0A,  // strict array
            0x00, 0x00, 0x00, 0x02,  // count = 2
            0x05,  // null
            0x01, 0x01  // boolean true
        ]
        let value = try decoder.decode(from: bytes)
        #expect(value == .strictArray([.null, .boolean(true)]))
    }

    // MARK: - Date

    @Test("Decode date zero timestamp")
    func decodeDateZero() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [0x0B, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let value = try decoder.decode(from: bytes)
        #expect(value == .date(0.0, timeZoneOffset: 0))
    }

    @Test("Decode date with timezone offset")
    func decodeDateWithTZ() throws {
        var decoder = AMF0Decoder()
        var bytes: [UInt8] = [0x0B]
        // timestamp = 0
        bytes.append(contentsOf: [0, 0, 0, 0, 0, 0, 0, 0])
        // tz = 120 = 0x0078
        bytes.append(contentsOf: [0x00, 0x78])
        let value = try decoder.decode(from: bytes)
        #expect(value == .date(0.0, timeZoneOffset: 120))
    }

    // MARK: - LongString

    @Test("Decode long string")
    func decodeLongString() throws {
        var decoder = AMF0Decoder()
        var bytes: [UInt8] = [0x0C, 0x00, 0x00, 0x00, 0x05]
        bytes.append(contentsOf: Array("hello".utf8))
        let value = try decoder.decode(from: bytes)
        #expect(value == .longString("hello"))
    }

    // MARK: - XML Document

    @Test("Decode XML document")
    func decodeXMLDocument() throws {
        var decoder = AMF0Decoder()
        let xml = "<root/>"
        var bytes: [UInt8] = [0x0F]
        let utf8 = Array(xml.utf8)
        bytes.append(UInt8((utf8.count >> 24) & 0xFF))
        bytes.append(UInt8((utf8.count >> 16) & 0xFF))
        bytes.append(UInt8((utf8.count >> 8) & 0xFF))
        bytes.append(UInt8(utf8.count & 0xFF))
        bytes.append(contentsOf: utf8)
        let value = try decoder.decode(from: bytes)
        #expect(value == .xmlDocument("<root/>"))
    }

    // MARK: - Typed Object

    @Test("Decode typed object")
    func decodeTypedObject() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [
            0x10,  // typed object
            0x00, 0x03, 0x46, 0x6F, 0x6F,  // class name "Foo"
            0x00, 0x01, 0x78,  // key "x"
            0x05,  // null
            0x00, 0x00, 0x09  // end
        ]
        let value = try decoder.decode(from: bytes)
        #expect(value == .typedObject(className: "Foo", properties: [("x", .null)]))
    }

    // MARK: - Multiple Values

    @Test("Decode multiple values from single buffer")
    func decodeMultipleValues() throws {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [0x05, 0x06, 0x0D]  // null, undefined, unsupported
        let values = try decoder.decodeAll(from: bytes)
        #expect(values == [.null, .undefined, .unsupported])
    }
}

@Suite("AMF0Decoder — Errors")
struct AMF0DecoderErrorTests {

    @Test("Decode empty data throws unexpectedEndOfData")
    func decodeEmptyData() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.unexpectedEndOfData) {
            try decoder.decode(from: [])
        }
    }

    @Test("Decode truncated number throws unexpectedEndOfData")
    func decodeTruncatedNumber() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.unexpectedEndOfData) {
            try decoder.decode(from: [0x00, 0x3F, 0xF0])  // only 2 of 8 bytes
        }
    }

    @Test("Decode truncated string throws unexpectedEndOfData")
    func decodeTruncatedString() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.unexpectedEndOfData) {
            try decoder.decode(from: [0x02, 0x00, 0x0A, 0x68, 0x69])  // says 10 bytes, only 2
        }
    }

    @Test("Decode unknown marker throws unknownTypeMarker")
    func decodeUnknownMarker() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.unknownTypeMarker(0xFF)) {
            try decoder.decode(from: [0xFF])
        }
    }

    @Test("Decode reserved marker 0x04 (MovieClip) throws reservedTypeMarker")
    func decodeReservedMovieClip() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.reservedTypeMarker(0x04)) {
            try decoder.decode(from: [0x04])
        }
    }

    @Test("Decode reserved marker 0x0E (RecordSet) throws reservedTypeMarker")
    func decodeReservedRecordSet() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.reservedTypeMarker(0x0E)) {
            try decoder.decode(from: [0x0E])
        }
    }

    @Test("Decode invalid reference throws invalidReference")
    func decodeInvalidReference() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.invalidReference(index: 5, tableSize: 0)) {
            try decoder.decode(from: [0x07, 0x00, 0x05])
        }
    }

    @Test("Decode max depth exceeded throws maxDepthExceeded")
    func decodeMaxDepthExceeded() {
        var decoder = AMF0Decoder(maxDepth: 2)
        // Build 3 levels of nesting: obj { "a": obj { "b": obj {} } }
        let bytes: [UInt8] = [
            0x03,  // level 0
            0x00, 0x01, 0x61,  // "a"
            0x03,  // level 1
            0x00, 0x01, 0x62,  // "b"
            0x03,  // level 2 -> exceeds maxDepth=2
            0x00, 0x00, 0x09,
            0x00, 0x00, 0x09,
            0x00, 0x00, 0x09
        ]
        #expect(throws: AMF0Error.maxDepthExceeded(limit: 2)) {
            try decoder.decode(from: bytes)
        }
    }

    @Test("Decode object missing end marker throws unexpectedEndOfData")
    func decodeObjectMissingEndMarker() {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [
            0x03,  // object
            0x00, 0x01, 0x61,  // key "a"
            0x05  // null
            // missing end marker
        ]
        #expect(throws: AMF0Error.unexpectedEndOfData) {
            try decoder.decode(from: bytes)
        }
    }

    @Test("Decode strict array truncated throws unexpectedEndOfData")
    func decodeStrictArrayTruncated() {
        var decoder = AMF0Decoder()
        let bytes: [UInt8] = [
            0x0A,  // strict array
            0x00, 0x00, 0x00, 0x05,  // count = 5
            0x05, 0x05, 0x05  // only 3 values
        ]
        #expect(throws: AMF0Error.unexpectedEndOfData) {
            try decoder.decode(from: bytes)
        }
    }

    @Test("Decode truncated boolean throws unexpectedEndOfData")
    func decodeTruncatedBoolean() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.unexpectedEndOfData) {
            try decoder.decode(from: [0x01])  // marker only, no value byte
        }
    }

    @Test("Decode truncated date throws unexpectedEndOfData")
    func decodeTruncatedDate() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.unexpectedEndOfData) {
            try decoder.decode(from: [0x0B, 0, 0, 0, 0])  // only 4 of 10 bytes
        }
    }

    @Test("Decode truncated reference throws unexpectedEndOfData")
    func decodeTruncatedReference() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.unexpectedEndOfData) {
            try decoder.decode(from: [0x07, 0x00])  // only 1 of 2 index bytes
        }
    }

    @Test("Decode objectEnd marker as standalone throws unknownTypeMarker")
    func decodeStandaloneObjectEnd() {
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.unknownTypeMarker(0x09)) {
            try decoder.decode(from: [0x09])
        }
    }

    // MARK: - Reset

    @Test("Reset clears reference table")
    func resetDecoder() throws {
        var decoder = AMF0Decoder()
        // Decode an object so reference table has an entry
        _ = try decoder.decode(from: [0x03, 0x00, 0x00, 0x09])
        decoder.reset()
        // Now reference 0 should fail
        #expect(throws: AMF0Error.invalidReference(index: 0, tableSize: 0)) {
            try decoder.decode(from: [0x07, 0x00, 0x00])
        }
    }
}
