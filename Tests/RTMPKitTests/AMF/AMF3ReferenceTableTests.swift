// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF3ReferenceTable")
struct AMF3ReferenceTableTests {

    @Test("stringReference returns nil for new string")
    func stringRefNil() {
        let table = AMF3ReferenceTable()
        #expect(table.stringReference(for: "hello") == nil)
    }

    @Test("addString then stringReference returns 0")
    func stringRefFirst() {
        var table = AMF3ReferenceTable()
        table.addString("hello")
        #expect(table.stringReference(for: "hello") == 0)
    }

    @Test("Multiple strings have sequential indices")
    func stringRefSequential() {
        var table = AMF3ReferenceTable()
        table.addString("a")
        table.addString("b")
        table.addString("c")
        #expect(table.stringReference(for: "a") == 0)
        #expect(table.stringReference(for: "b") == 1)
        #expect(table.stringReference(for: "c") == 2)
    }

    @Test("objectReference returns nil for new object")
    func objectRefNil() {
        let table = AMF3ReferenceTable()
        #expect(table.objectReference(for: .null) == nil)
    }

    @Test("addObject then objectReference returns index")
    func objectRefFound() {
        var table = AMF3ReferenceTable()
        table.addObject(.string("test"))
        #expect(table.objectReference(for: .string("test")) == 0)
    }

    @Test("traitsReference follows same pattern")
    func traitsRefPattern() {
        var table = AMF3ReferenceTable()
        let traits = AMF3Traits.anonymous
        #expect(table.traitsReference(for: traits) == nil)
        table.addTraits(traits)
        #expect(table.traitsReference(for: traits) == 0)
    }

    @Test("reset clears all three tables")
    func resetClearsAll() {
        var table = AMF3ReferenceTable()
        table.addString("s")
        table.addObject(.null)
        table.addTraits(.anonymous)
        table.reset()
        #expect(table.strings.isEmpty)
        #expect(table.objects.isEmpty)
        #expect(table.traits.isEmpty)
    }

    @Test("replaceObject updates existing entry")
    func replaceObject() {
        var table = AMF3ReferenceTable()
        table.addObject(.null)
        table.replaceObject(at: 0, with: .integer(42))
        #expect(table.objects[0] == .integer(42))
    }
}
