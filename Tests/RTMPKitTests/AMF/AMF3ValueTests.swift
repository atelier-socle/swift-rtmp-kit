// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF3Value — Type Instantiation")
struct AMF3ValueTypeTests {

    @Test("All 18 cases can be instantiated")
    func allCases() {
        let values: [AMF3Value] = [
            .undefined, .null, .false, .true,
            .integer(42), .double(3.14), .string("hello"),
            .xmlDocument("<xml/>"), .date(0),
            .array(dense: [], associative: [:]),
            .object(AMF3Object(traits: .anonymous)),
            .xml("<e4x/>"), .byteArray([1, 2, 3]),
            .vectorInt([1], fixed: false),
            .vectorUInt([1], fixed: true),
            .vectorDouble([1.0], fixed: false),
            .vectorObject([.null], typeName: "", fixed: false),
            .dictionary([(key: .string("a"), value: .integer(1))], weakKeys: false)
        ]
        #expect(values.count == 18)
    }
}

@Suite("AMF3Value — Convenience Accessors")
struct AMF3ValueAccessorTests {

    @Test("isNull: null and undefined are null")
    func isNullTrue() {
        #expect(AMF3Value.null.isNull == true)
        #expect(AMF3Value.undefined.isNull == true)
    }

    @Test("isNull: other values are not null")
    func isNullFalse() {
        #expect(AMF3Value.false.isNull == false)
        #expect(AMF3Value.string("x").isNull == false)
        #expect(AMF3Value.integer(0).isNull == false)
    }

    @Test("stringValue: string, xmlDocument, xml")
    func stringValueExtract() {
        #expect(AMF3Value.string("hello").stringValue == "hello")
        #expect(AMF3Value.xmlDocument("<x/>").stringValue == "<x/>")
        #expect(AMF3Value.xml("<y/>").stringValue == "<y/>")
    }

    @Test("stringValue: non-string returns nil")
    func stringValueNil() {
        #expect(AMF3Value.integer(1).stringValue == nil)
        #expect(AMF3Value.null.stringValue == nil)
    }

    @Test("doubleValue: extracts double")
    func doubleValueExtract() {
        #expect(AMF3Value.double(3.14).doubleValue == 3.14)
    }

    @Test("doubleValue: non-double returns nil")
    func doubleValueNil() {
        #expect(AMF3Value.integer(42).doubleValue == nil)
    }

    @Test("intValue: extracts integer")
    func intValueExtract() {
        #expect(AMF3Value.integer(42).intValue == 42)
    }

    @Test("intValue: non-integer returns nil")
    func intValueNil() {
        #expect(AMF3Value.double(42.0).intValue == nil)
    }

    @Test("boolValue: true and false")
    func boolValueExtract() {
        #expect(AMF3Value.true.boolValue == true)
        #expect(AMF3Value.false.boolValue == false)
    }

    @Test("boolValue: non-bool returns nil")
    func boolValueNil() {
        #expect(AMF3Value.null.boolValue == nil)
    }

    @Test("byteArrayValue: extracts bytes")
    func byteArrayValueExtract() {
        #expect(AMF3Value.byteArray([1, 2, 3]).byteArrayValue == [1, 2, 3])
    }

    @Test("byteArrayValue: non-byteArray returns nil")
    func byteArrayValueNil() {
        #expect(AMF3Value.string("abc").byteArrayValue == nil)
    }
}

@Suite("AMF3Value — Equatable")
struct AMF3ValueEqualityTests {

    @Test("null == null")
    func nullEquality() {
        #expect(AMF3Value.null == AMF3Value.null)
    }

    @Test("integer equality")
    func integerEquality() {
        #expect(AMF3Value.integer(42) == AMF3Value.integer(42))
        #expect(AMF3Value.integer(42) != AMF3Value.integer(43))
    }

    @Test("string equality")
    func stringEquality() {
        #expect(AMF3Value.string("a") == AMF3Value.string("a"))
        #expect(AMF3Value.string("a") != AMF3Value.string("b"))
    }

    @Test("array equality")
    func arrayEquality() {
        let a = AMF3Value.array(dense: [.null], associative: [:])
        let b = AMF3Value.array(dense: [.null], associative: [:])
        #expect(a == b)
    }

    @Test("different types are not equal")
    func differentTypes() {
        #expect(AMF3Value.null != AMF3Value.undefined)
        #expect(AMF3Value.integer(0) != AMF3Value.double(0.0))
    }

    @Test("dictionary equality preserves order")
    func dictionaryEquality() {
        let a = AMF3Value.dictionary(
            [(key: .string("a"), value: .integer(1))], weakKeys: false
        )
        let b = AMF3Value.dictionary(
            [(key: .string("a"), value: .integer(1))], weakKeys: false
        )
        #expect(a == b)
    }
}
