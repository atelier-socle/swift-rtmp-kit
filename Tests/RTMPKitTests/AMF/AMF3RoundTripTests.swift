// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF3 — Round Trip")
struct AMF3RoundTripTests {

    private func roundtrip(_ value: AMF3Value) throws {
        var encoder = AMF3Encoder()
        let bytes = try encoder.encode(value)
        var decoder = AMF3Decoder()
        let (decoded, consumed) = try decoder.decode(from: bytes)
        #expect(decoded == value)
        #expect(consumed == bytes.count)
    }

    @Test("Roundtrip: undefined")
    func undefined() throws {
        try roundtrip(.undefined)
    }

    @Test("Roundtrip: null")
    func null() throws {
        try roundtrip(.null)
    }

    @Test("Roundtrip: false")
    func boolFalse() throws {
        try roundtrip(.false)
    }

    @Test("Roundtrip: true")
    func boolTrue() throws {
        try roundtrip(.true)
    }

    @Test("Roundtrip: integer(42)")
    func integer42() throws {
        try roundtrip(.integer(42))
    }

    @Test("Roundtrip: double(3.14)")
    func double314() throws {
        try roundtrip(.double(3.14))
    }

    @Test("Roundtrip: string('test')")
    func stringTest() throws {
        try roundtrip(.string("test"))
    }

    @Test("Roundtrip: max positive 29-bit integer")
    func maxPositiveInt() throws {
        try roundtrip(.integer(268_435_455))
    }

    @Test("Roundtrip: min negative 29-bit integer")
    func minNegativeInt() throws {
        try roundtrip(.integer(-268_435_456))
    }

    @Test("Roundtrip: Unicode string")
    func unicodeString() throws {
        try roundtrip(.string("日本語テスト"))
    }

    @Test("Roundtrip: ByteArray with 256 bytes")
    func largeByteArray() throws {
        try roundtrip(.byteArray(Array(0..<256).map { UInt8($0 & 0xFF) }))
    }

    @Test("Roundtrip: array with mixed dense/associative")
    func mixedArray() throws {
        try roundtrip(
            .array(
                dense: [.integer(1), .string("two"), .null],
                associative: ["key": .double(3.14)]
            ))
    }

    @Test("Roundtrip: anonymous dynamic object")
    func anonymousObject() throws {
        let obj = AMF3Object(
            traits: .anonymous,
            dynamicProperties: ["name": .string("test"), "value": .integer(42)]
        )
        try roundtrip(.object(obj))
    }

    @Test("Roundtrip: sealed object")
    func sealedObject() throws {
        let traits = AMF3Traits.sealed(className: "com.example.Point", properties: ["x", "y"])
        let obj = AMF3Object(
            traits: traits,
            sealedProperties: ["x": .double(1.5), "y": .double(2.5)]
        )
        try roundtrip(.object(obj))
    }

    @Test("Roundtrip: nested object in array")
    func nestedStructure() throws {
        let inner = AMF3Object(
            traits: .anonymous,
            dynamicProperties: ["v": .integer(1)]
        )
        try roundtrip(
            .array(
                dense: [.object(inner), .string("end")],
                associative: [:]
            ))
    }

    @Test("Roundtrip: string reference table with 3 identical strings")
    func stringReferences() throws {
        var encoder = AMF3Encoder()
        let values: [AMF3Value] = [.string("same"), .string("same"), .string("same")]
        let bytes = try encoder.encodeAll(values)
        var decoder = AMF3Decoder()
        let decoded = try decoder.decodeAll(from: bytes)
        #expect(decoded == values)
    }

    @Test("Roundtrip: vectorInt with mixed positive/negative")
    func vectorIntMixed() throws {
        try roundtrip(.vectorInt([-100, 0, 100, Int32.max, Int32.min], fixed: true))
    }

    @Test("Roundtrip: dictionary with complex keys")
    func dictionaryComplexKeys() throws {
        try roundtrip(
            .dictionary(
                [
                    (key: .string("a"), value: .integer(1)),
                    (key: .integer(42), value: .string("forty-two"))
                ],
                weakKeys: false
            ))
    }

    @Test("Roundtrip: date")
    func dateRoundtrip() throws {
        try roundtrip(.date(1_709_683_200_000))
    }

    @Test("Roundtrip: xmlDocument")
    func xmlDocumentRoundtrip() throws {
        try roundtrip(.xmlDocument("<root><child/></root>"))
    }

    @Test("Roundtrip: xml (E4X)")
    func xmlRoundtrip() throws {
        try roundtrip(.xml("<e4x>content</e4x>"))
    }
}
