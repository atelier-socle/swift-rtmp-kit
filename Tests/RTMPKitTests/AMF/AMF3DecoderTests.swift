// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF3Decoder — Scalar Types")
struct AMF3DecoderScalarTests {

    @Test("Decode undefined")
    func decodeUndefined() throws {
        var decoder = AMF3Decoder()
        let (value, consumed) = try decoder.decode(from: [0x00])
        #expect(value == .undefined)
        #expect(consumed == 1)
    }

    @Test("Decode null")
    func decodeNull() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x01])
        #expect(value == .null)
    }

    @Test("Decode false")
    func decodeFalse() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x02])
        #expect(value == .false)
    }

    @Test("Decode true")
    func decodeTrue() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x03])
        #expect(value == .true)
    }

    @Test("Decode integer 0")
    func decodeIntegerZero() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x04, 0x00])
        #expect(value == .integer(0))
    }

    @Test("Decode integer 127")
    func decodeInteger127() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x04, 0x7F])
        #expect(value == .integer(127))
    }

    @Test("Decode integer 128 (2-byte U29)")
    func decodeInteger128() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x04, 0x81, 0x00])
        #expect(value == .integer(128))
    }

    @Test("Decode integer 16384 (3-byte U29)")
    func decodeInteger16384() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x04, 0x81, 0x80, 0x00])
        #expect(value == .integer(16384))
    }

    @Test("Decode double 0.0")
    func decodeDoubleZero() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(
            from: [0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        )
        #expect(value == .double(0.0))
    }

    @Test("Decode double 1.0")
    func decodeDoubleOne() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(
            from: [0x05, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        )
        #expect(value == .double(1.0))
    }

    @Test("Decode empty string")
    func decodeEmptyString() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x06, 0x01])
        #expect(value == .string(""))
    }

    @Test("Decode 'hello'")
    func decodeHello() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x06, 0x0B, 0x68, 0x65, 0x6C, 0x6C, 0x6F])
        #expect(value == .string("hello"))
    }
}

@Suite("AMF3Decoder — Complex Types and Errors")
struct AMF3DecoderComplexTests {

    @Test("Decode string reference")
    func decodeStringReference() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encodeAll([.string("hello"), .string("hello")])
        var decoder = AMF3Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values == [.string("hello"), .string("hello")])
    }

    @Test("Decode byteArray")
    func decodeByteArray() throws {
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: [0x0C, 0x07, 0x01, 0x02, 0x03])
        #expect(value == .byteArray([1, 2, 3]))
    }

    @Test("Decode date")
    func decodeDate() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.date(1234567890.0))
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: bytes)
        #expect(value == .date(1234567890.0))
    }

    @Test("Decode dense array")
    func decodeDenseArray() throws {
        var encoder = AMF3Encoder()
        let original = AMF3Value.array(dense: [.integer(1), .integer(2)], associative: [:])
        let bytes = try encoder.encode(original)
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: bytes)
        #expect(value == original)
    }

    @Test("Decode anonymous dynamic object")
    func decodeAnonymousObject() throws {
        var encoder = AMF3Encoder()
        let obj = AMF3Object(
            traits: .anonymous,
            dynamicProperties: ["x": .integer(42)]
        )
        let original = AMF3Value.object(obj)
        let bytes = try encoder.encode(original)
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: bytes)
        #expect(value == original)
    }

    @Test("Decode sealed object with traits")
    func decodeSealedObject() throws {
        var encoder = AMF3Encoder()
        let traits = AMF3Traits.sealed(className: "Point", properties: ["x", "y"])
        let obj = AMF3Object(
            traits: traits,
            sealedProperties: ["x": .integer(10), "y": .integer(20)]
        )
        let bytes = try encoder.encode(.object(obj))
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: bytes)
        if case let .object(decoded) = value {
            #expect(decoded.traits == traits)
            #expect(decoded.sealedProperties["x"] == .integer(10))
            #expect(decoded.sealedProperties["y"] == .integer(20))
        } else {
            Issue.record("Expected object")
        }
    }

    @Test("Decode traits reference")
    func decodeTraitsReference() throws {
        var encoder = AMF3Encoder()
        let traits = AMF3Traits.sealed(className: "Pt", properties: ["x"])
        let obj1 = AMF3Object(traits: traits, sealedProperties: ["x": .integer(1)])
        let obj2 = AMF3Object(traits: traits, sealedProperties: ["x": .integer(2)])
        let bytes = try encoder.encodeAll([.object(obj1), .object(obj2)])
        var decoder = AMF3Decoder()
        let values = try decoder.decodeAll(from: bytes)
        if case let .object(d1) = values[0], case let .object(d2) = values[1] {
            #expect(d1.traits == traits)
            #expect(d2.traits == traits)
            #expect(d1.sealedProperties["x"] == .integer(1))
            #expect(d2.sealedProperties["x"] == .integer(2))
        } else {
            Issue.record("Expected two objects")
        }
    }

    @Test("Decode vectorInt")
    func decodeVectorInt() throws {
        var encoder = AMF3Encoder()
        let original = AMF3Value.vectorInt([1, -1, 0, 2_000_000], fixed: true)
        let bytes = try encoder.encode(original)
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: bytes)
        #expect(value == original)
    }

    @Test("Decode vectorUInt")
    func decodeVectorUInt() throws {
        var encoder = AMF3Encoder()
        let original = AMF3Value.vectorUInt([0, 100, 4_000_000_000], fixed: false)
        let bytes = try encoder.encode(original)
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: bytes)
        #expect(value == original)
    }

    @Test("Decode vectorDouble")
    func decodeVectorDouble() throws {
        var encoder = AMF3Encoder()
        let original = AMF3Value.vectorDouble([1.1, 2.2, 3.3], fixed: true)
        let bytes = try encoder.encode(original)
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: bytes)
        #expect(value == original)
    }

    @Test("Decode vectorObject")
    func decodeVectorObject() throws {
        var encoder = AMF3Encoder()
        let original = AMF3Value.vectorObject(
            [.string("a"), .string("b")], typeName: "String", fixed: false
        )
        let bytes = try encoder.encode(original)
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: bytes)
        #expect(value == original)
    }

    @Test("Decode dictionary")
    func decodeDictionary() throws {
        var encoder = AMF3Encoder()
        let original = AMF3Value.dictionary(
            [
                (key: .string("a"), value: .integer(1)),
                (key: .string("b"), value: .integer(2))
            ],
            weakKeys: false
        )
        let bytes = try encoder.encode(original)
        var decoder = AMF3Decoder()
        let (value, _) = try decoder.decode(from: bytes)
        #expect(value == original)
    }

    @Test("Unknown type marker throws")
    func unknownMarker() {
        var decoder = AMF3Decoder()
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: [0xFF])
        }
    }

    @Test("Truncated input throws")
    func truncatedInput() {
        var decoder = AMF3Decoder()
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: [0x05, 0x00])  // double needs 8 bytes
        }
    }

    @Test("Empty input throws")
    func emptyInput() {
        var decoder = AMF3Decoder()
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: [])
        }
    }
}
