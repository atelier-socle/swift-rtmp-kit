// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF0Decoder — Error Paths")
struct AMF0DecoderErrorCoverageTests {

    @Test("maxDepthExceeded on deeply nested object")
    func maxDepthExceededObject() {
        // Build an object nested beyond the max depth
        var encoder = AMF0Encoder()
        var value: AMF0Value = .string("leaf")
        for i in (0..<33).reversed() {
            value = .object([("level\(i)", value)])
        }
        let bytes = encoder.encode(value)
        var decoder = AMF0Decoder(maxDepth: 32)
        #expect(throws: AMF0Error.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("maxDepthExceeded on deeply nested ECMA array")
    func maxDepthExceededECMAArray() {
        // Build a structure that nests ECMA arrays beyond depth
        var encoder = AMF0Encoder()
        var value: AMF0Value = .string("leaf")
        // Alternate between ecmaArray and object to test both paths
        for i in (0..<17).reversed() {
            if i % 2 == 0 {
                value = .ecmaArray([("level\(i)", value)])
            } else {
                value = .object([("level\(i)", value)])
            }
        }
        let bytes = encoder.encode(value)
        var decoder = AMF0Decoder(maxDepth: 8)
        #expect(throws: AMF0Error.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("maxDepthExceeded on deeply nested strict array")
    func maxDepthExceededStrictArray() {
        var encoder = AMF0Encoder()
        var value: AMF0Value = .number(42)
        for _ in (0..<35).reversed() {
            value = .strictArray([value])
        }
        let bytes = encoder.encode(value)
        var decoder = AMF0Decoder(maxDepth: 32)
        #expect(throws: AMF0Error.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("maxDepthExceeded on deeply nested typed object")
    func maxDepthExceededTypedObject() {
        var encoder = AMF0Encoder()
        var value: AMF0Value = .string("leaf")
        for _ in (0..<35).reversed() {
            value = .typedObject(
                className: "C", properties: [("p", value)])
        }
        let bytes = encoder.encode(value)
        var decoder = AMF0Decoder(maxDepth: 32)
        #expect(throws: AMF0Error.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid UTF-8 string throws invalidUTF8String")
    func invalidUTF8String() {
        // Build a string marker + length + invalid UTF-8 bytes
        var bytes: [UInt8] = [AMF0Value.Marker.string]
        // Length = 3 (uint16 BE)
        bytes.append(0x00)
        bytes.append(0x03)
        // Invalid UTF-8: 0xFE is not valid in UTF-8
        bytes.append(contentsOf: [0xFE, 0xFF, 0x80])
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("long string with truncated data throws unexpectedEndOfData")
    func longStringTruncated() {
        // Long string marker + length=100 but only 10 bytes of data
        var bytes: [UInt8] = [AMF0Value.Marker.longString]
        // Length = 100 (uint32 BE)
        bytes.append(contentsOf: [0x00, 0x00, 0x00, 0x64])
        // Only 10 bytes
        bytes.append(contentsOf: Array(repeating: 0x41, count: 10))
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("readUInt32BE with insufficient data throws")
    func readUInt32BEInsufficient() {
        // ECMA array marker, but only 2 bytes of count instead of 4
        let bytes: [UInt8] = [AMF0Value.Marker.ecmaArray, 0x00, 0x00]
        var decoder = AMF0Decoder()
        #expect(throws: AMF0Error.self) {
            _ = try decoder.decode(from: bytes)
        }
    }
}

@Suite("AMF0Error — Error Descriptions")
struct AMF0ErrorDescriptionCoverageTests {

    @Test("invalidUTF8String description")
    func invalidUTF8Description() {
        let err = AMF0Error.invalidUTF8String
        #expect(err.description.contains("invalid UTF-8"))
    }

    @Test("stringTooLong description")
    func stringTooLongDescription() {
        let err = AMF0Error.stringTooLong(length: 70000)
        #expect(err.description.contains("70000"))
    }

    @Test("reservedTypeMarker description")
    func reservedTypeMarkerDescription() {
        let err = AMF0Error.reservedTypeMarker(0x04)
        #expect(err.description.contains("reserved"))
    }

    @Test("unknownTypeMarker description")
    func unknownTypeMarkerDescription() {
        let err = AMF0Error.unknownTypeMarker(0xFF)
        #expect(err.description.contains("FF"))
    }

    @Test("maxDepthExceeded description")
    func maxDepthExceededDescription() {
        let err = AMF0Error.maxDepthExceeded(limit: 32)
        #expect(err.description.contains("32"))
    }
}
