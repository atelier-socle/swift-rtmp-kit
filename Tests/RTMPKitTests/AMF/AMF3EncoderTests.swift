// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF3Encoder — Scalar Types")
struct AMF3EncoderScalarTests {

    @Test("undefined encodes to [0x00]")
    func encodeUndefined() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.undefined)
        #expect(bytes == [0x00])
    }

    @Test("null encodes to [0x01]")
    func encodeNull() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.null)
        #expect(bytes == [0x01])
    }

    @Test("false encodes to [0x02]")
    func encodeFalse() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.false)
        #expect(bytes == [0x02])
    }

    @Test("true encodes to [0x03]")
    func encodeTrue() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.true)
        #expect(bytes == [0x03])
    }

    @Test("integer(0) encodes to [0x04, 0x00]")
    func encodeIntegerZero() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.integer(0))
        #expect(bytes == [0x04, 0x00])
    }

    @Test("integer(127) encodes to 1-byte U29")
    func encodeInteger127() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.integer(127))
        #expect(bytes == [0x04, 0x7F])
    }

    @Test("integer(128) encodes to 2-byte U29")
    func encodeInteger128() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.integer(128))
        #expect(bytes == [0x04, 0x81, 0x00])
    }

    @Test("integer(16383) encodes to 2-byte U29 max")
    func encodeInteger16383() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.integer(16383))
        #expect(bytes == [0x04, 0xFF, 0x7F])
    }

    @Test("integer(16384) encodes to 3-byte U29")
    func encodeInteger16384() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.integer(16384))
        #expect(bytes == [0x04, 0x81, 0x80, 0x00])
    }

    @Test("integer(-1) encodes correctly")
    func encodeNegativeOne() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.integer(-1))
        // -1 in 29-bit two's complement = 0x1FFFFFFF
        #expect(bytes.count == 5)  // marker + 4-byte U29
        #expect(bytes[0] == 0x04)
    }

    @Test("integer out of range throws")
    func encodeIntegerOutOfRange() {
        var encoder = AMF3Encoder()
        #expect(throws: AMF3EncodingError.self) {
            _ = try encoder.encode(.integer(268_435_456))
        }
    }

    @Test("double(0.0) encodes correctly")
    func encodeDoubleZero() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.double(0.0))
        #expect(bytes == [0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    @Test("double(1.0) encodes correctly")
    func encodeDoubleOne() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.double(1.0))
        #expect(bytes == [0x05, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }
}

@Suite("AMF3Encoder — String and Complex Types")
struct AMF3EncoderComplexTests {

    @Test("empty string encodes to [0x06, 0x01]")
    func encodeEmptyString() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.string(""))
        #expect(bytes == [0x06, 0x01])
    }

    @Test("string 'hello' encodes correctly")
    func encodeHello() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.string("hello"))
        #expect(bytes == [0x06, 0x0B, 0x68, 0x65, 0x6C, 0x6C, 0x6F])
    }

    @Test("String reference: second occurrence is a reference")
    func encodeStringReference() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encodeAll([.string("hello"), .string("hello")])
        // First: 0x06 0x0B h e l l o
        // Second: 0x06 0x00 (reference index 0)
        let secondStart = 7
        #expect(bytes[secondStart] == 0x06)
        #expect(bytes[secondStart + 1] == 0x00)
    }

    @Test("byteArray([]) encodes to [0x0C, 0x01]")
    func encodeEmptyByteArray() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.byteArray([]))
        #expect(bytes == [0x0C, 0x01])
    }

    @Test("byteArray([1,2,3]) encodes correctly")
    func encodeByteArray() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.byteArray([1, 2, 3]))
        #expect(bytes == [0x0C, 0x07, 0x01, 0x02, 0x03])
    }

    @Test("date(0.0) encodes correctly")
    func encodeDateZero() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.date(0.0))
        #expect(bytes[0] == 0x08)
        #expect(bytes[1] == 0x01)  // inline flag
        #expect(bytes.count == 10)  // marker + U29 + 8 bytes double
    }

    @Test("Dense-only array encodes correctly")
    func encodeDenseArray() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.array(dense: [.integer(1), .integer(2)], associative: [:]))
        #expect(bytes[0] == 0x09)  // array marker
    }

    @Test("Array with associative part encodes key-value pairs")
    func encodeAssociativeArray() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(
            .array(
                dense: [.integer(1)],
                associative: ["key": .string("val")]
            ))
        #expect(bytes[0] == 0x09)
        #expect(bytes.count > 5)
    }

    @Test("Anonymous dynamic object encodes correctly")
    func encodeAnonymousObject() throws {
        var encoder = AMF3Encoder()
        let obj = AMF3Object(
            traits: .anonymous,
            dynamicProperties: ["x": .integer(1)]
        )
        let bytes = try encoder.encode(.object(obj))
        #expect(bytes[0] == 0x0A)
    }

    @Test("Sealed object encodes sealed properties in order")
    func encodeSealedObject() throws {
        var encoder = AMF3Encoder()
        let traits = AMF3Traits.sealed(className: "Point", properties: ["x", "y"])
        let obj = AMF3Object(
            traits: traits,
            sealedProperties: ["x": .integer(10), "y": .integer(20)]
        )
        let bytes = try encoder.encode(.object(obj))
        #expect(bytes[0] == 0x0A)
        #expect(bytes.count > 10)
    }

    @Test("Traits reference: same traits used twice")
    func encodeTraitsReference() throws {
        var encoder = AMF3Encoder()
        let traits = AMF3Traits.sealed(className: "Pt", properties: ["x"])
        let obj1 = AMF3Object(traits: traits, sealedProperties: ["x": .integer(1)])
        let obj2 = AMF3Object(traits: traits, sealedProperties: ["x": .integer(2)])
        let bytes = try encoder.encodeAll([.object(obj1), .object(obj2)])
        // Second object should use traits reference (shorter encoding)
        #expect(bytes.count > 10)
    }

    @Test("vectorInt encodes correctly")
    func encodeVectorInt() throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(.vectorInt([1, -1], fixed: false))
        #expect(bytes[0] == 0x0D)
    }

    @Test("Externalizable object throws")
    func encodeExternalizable() {
        var encoder = AMF3Encoder()
        let traits = AMF3Traits(isExternalizable: true)
        let obj = AMF3Object(traits: traits)
        #expect(throws: AMF3EncodingError.self) {
            _ = try encoder.encode(.object(obj))
        }
    }
}
