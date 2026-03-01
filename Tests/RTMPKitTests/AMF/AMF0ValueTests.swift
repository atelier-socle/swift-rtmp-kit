// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF0Value")
struct AMF0ValueTests {

    // MARK: - Equatable

    @Test("Numbers with same value are equal")
    func numberEquality() {
        #expect(AMF0Value.number(42.0) == AMF0Value.number(42.0))
    }

    @Test("Numbers with different values are not equal")
    func numberInequality() {
        #expect(AMF0Value.number(1.0) != AMF0Value.number(2.0))
    }

    @Test("NaN equals NaN via bitPattern comparison")
    func nanEquality() {
        #expect(AMF0Value.number(.nan) == AMF0Value.number(.nan))
    }

    @Test("Booleans with same value are equal")
    func booleanEquality() {
        #expect(AMF0Value.boolean(true) == AMF0Value.boolean(true))
        #expect(AMF0Value.boolean(false) == AMF0Value.boolean(false))
    }

    @Test("Booleans with different values are not equal")
    func booleanInequality() {
        #expect(AMF0Value.boolean(true) != AMF0Value.boolean(false))
    }

    @Test("Strings with same value are equal")
    func stringEquality() {
        #expect(AMF0Value.string("hello") == AMF0Value.string("hello"))
    }

    @Test("Strings with different values are not equal")
    func stringInequality() {
        #expect(AMF0Value.string("hello") != AMF0Value.string("world"))
    }

    @Test("Objects with same pairs in same order are equal")
    func objectEqualitySameOrder() {
        let a = AMF0Value.object([("x", .number(1)), ("y", .number(2))])
        let b = AMF0Value.object([("x", .number(1)), ("y", .number(2))])
        #expect(a == b)
    }

    @Test("Objects with same pairs in different order are not equal")
    func objectEqualityDifferentOrder() {
        let a = AMF0Value.object([("x", .number(1)), ("y", .number(2))])
        let b = AMF0Value.object([("y", .number(2)), ("x", .number(1))])
        #expect(a != b)
    }

    @Test("Objects with different pair count are not equal")
    func objectDifferentCount() {
        let a = AMF0Value.object([("x", .number(1))])
        let b = AMF0Value.object([("x", .number(1)), ("y", .number(2))])
        #expect(a != b)
    }

    @Test("Null equals null")
    func nullEquality() {
        #expect(AMF0Value.null == AMF0Value.null)
    }

    @Test("Undefined equals undefined")
    func undefinedEquality() {
        #expect(AMF0Value.undefined == AMF0Value.undefined)
    }

    @Test("Null is not equal to undefined")
    func nullNotUndefined() {
        #expect(AMF0Value.null != AMF0Value.undefined)
    }

    @Test("Different types are not equal")
    func differentTypesNotEqual() {
        #expect(AMF0Value.number(0) != AMF0Value.boolean(false))
        #expect(AMF0Value.string("") != AMF0Value.null)
        #expect(AMF0Value.null != AMF0Value.unsupported)
    }

    @Test("Date equality compares ms and timezone")
    func dateEquality() {
        #expect(AMF0Value.date(1000.0, timeZoneOffset: 0) == AMF0Value.date(1000.0, timeZoneOffset: 0))
        #expect(AMF0Value.date(1000.0, timeZoneOffset: 0) != AMF0Value.date(1000.0, timeZoneOffset: 60))
        #expect(AMF0Value.date(1000.0, timeZoneOffset: 0) != AMF0Value.date(2000.0, timeZoneOffset: 0))
    }

    @Test("Unsupported equals unsupported")
    func unsupportedEquality() {
        #expect(AMF0Value.unsupported == AMF0Value.unsupported)
    }

    @Test("Reference equality by index")
    func referenceEquality() {
        #expect(AMF0Value.reference(0) == AMF0Value.reference(0))
        #expect(AMF0Value.reference(0) != AMF0Value.reference(1))
    }

    @Test("ECMAArray equality preserves order")
    func ecmaArrayEquality() {
        let a = AMF0Value.ecmaArray([("a", .number(1)), ("b", .number(2))])
        let b = AMF0Value.ecmaArray([("a", .number(1)), ("b", .number(2))])
        let c = AMF0Value.ecmaArray([("b", .number(2)), ("a", .number(1))])
        #expect(a == b)
        #expect(a != c)
    }

    @Test("StrictArray equality")
    func strictArrayEquality() {
        let a = AMF0Value.strictArray([.number(1), .string("x")])
        let b = AMF0Value.strictArray([.number(1), .string("x")])
        let c = AMF0Value.strictArray([.string("x"), .number(1)])
        #expect(a == b)
        #expect(a != c)
    }

    @Test("TypedObject equality includes class name and properties")
    func typedObjectEquality() {
        let a = AMF0Value.typedObject(className: "Foo", properties: [("x", .number(1))])
        let b = AMF0Value.typedObject(className: "Foo", properties: [("x", .number(1))])
        let c = AMF0Value.typedObject(className: "Bar", properties: [("x", .number(1))])
        #expect(a == b)
        #expect(a != c)
    }

    @Test("LongString equals longString")
    func longStringEquality() {
        #expect(AMF0Value.longString("abc") == AMF0Value.longString("abc"))
        #expect(AMF0Value.longString("abc") != AMF0Value.longString("def"))
    }

    @Test("XMLDocument equality")
    func xmlDocumentEquality() {
        #expect(AMF0Value.xmlDocument("<a/>") == AMF0Value.xmlDocument("<a/>"))
        #expect(AMF0Value.xmlDocument("<a/>") != AMF0Value.xmlDocument("<b/>"))
    }

    // MARK: - Convenience Accessors

    @Test("numberValue accessor")
    func numberValueAccessor() {
        #expect(AMF0Value.number(42.0).numberValue == 42.0)
        #expect(AMF0Value.string("x").numberValue == nil)
    }

    @Test("booleanValue accessor")
    func booleanValueAccessor() {
        #expect(AMF0Value.boolean(true).booleanValue == true)
        #expect(AMF0Value.number(1.0).booleanValue == nil)
    }

    @Test("stringValue accessor returns for string and longString")
    func stringValueAccessor() {
        #expect(AMF0Value.string("hi").stringValue == "hi")
        #expect(AMF0Value.longString("long").stringValue == "long")
        #expect(AMF0Value.number(1.0).stringValue == nil)
    }

    @Test("objectProperties accessor")
    func objectPropertiesAccessor() {
        let props: [(String, AMF0Value)] = [("k", .null)]
        #expect(AMF0Value.object(props).objectProperties?.count == 1)
        #expect(AMF0Value.null.objectProperties == nil)
    }

    @Test("ecmaArrayEntries accessor")
    func ecmaArrayEntriesAccessor() {
        let entries: [(String, AMF0Value)] = [("k", .null)]
        #expect(AMF0Value.ecmaArray(entries).ecmaArrayEntries?.count == 1)
        #expect(AMF0Value.null.ecmaArrayEntries == nil)
    }

    @Test("arrayElements accessor")
    func arrayElementsAccessor() {
        #expect(AMF0Value.strictArray([.null]).arrayElements?.count == 1)
        #expect(AMF0Value.null.arrayElements == nil)
    }

    @Test("isNull returns true only for null")
    func isNullAccessor() {
        #expect(AMF0Value.null.isNull)
        #expect(!AMF0Value.undefined.isNull)
    }

    @Test("isUndefined returns true only for undefined")
    func isUndefinedAccessor() {
        #expect(AMF0Value.undefined.isUndefined)
        #expect(!AMF0Value.null.isUndefined)
    }

    // MARK: - Description

    @Test("Description produces readable output for all types")
    func descriptionCoversAllTypes() {
        let cases: [AMF0Value] = [
            .number(42), .boolean(true), .string("hi"), .object([]),
            .null, .undefined, .reference(0), .ecmaArray([]),
            .strictArray([]), .date(0, timeZoneOffset: 0), .longString("x"),
            .unsupported, .xmlDocument("<a/>"),
            .typedObject(className: "C", properties: [])
        ]
        for value in cases {
            #expect(value.description.hasPrefix("AMF0."))
        }
    }
}
