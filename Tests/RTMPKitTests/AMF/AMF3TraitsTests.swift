// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AMF3Traits")
struct AMF3TraitsTests {

    @Test("anonymous preset defaults")
    func anonymousDefaults() {
        let traits = AMF3Traits.anonymous
        #expect(traits.className == "")
        #expect(traits.isDynamic == true)
        #expect(traits.isExternalizable == false)
        #expect(traits.properties.isEmpty)
    }

    @Test("sealed factory creates non-dynamic traits")
    func sealedFactory() {
        let traits = AMF3Traits.sealed(
            className: "com.example.User",
            properties: ["name", "age"]
        )
        #expect(traits.className == "com.example.User")
        #expect(traits.isDynamic == false)
        #expect(traits.isExternalizable == false)
        #expect(traits.properties == ["name", "age"])
    }

    @Test("Full init stores all fields")
    func fullInit() {
        let traits = AMF3Traits(
            className: "Test",
            isDynamic: true,
            isExternalizable: true,
            properties: ["a", "b"]
        )
        #expect(traits.className == "Test")
        #expect(traits.isDynamic == true)
        #expect(traits.isExternalizable == true)
        #expect(traits.properties == ["a", "b"])
    }

    @Test("Equatable: same traits are equal")
    func equalTraits() {
        let a = AMF3Traits(className: "X", isDynamic: false, properties: ["p"])
        let b = AMF3Traits(className: "X", isDynamic: false, properties: ["p"])
        #expect(a == b)
    }

    @Test("Equatable: different className → not equal")
    func differentClassName() {
        let a = AMF3Traits(className: "A")
        let b = AMF3Traits(className: "B")
        #expect(a != b)
    }

    @Test("Equatable: different properties order → not equal")
    func differentPropertyOrder() {
        let a = AMF3Traits.sealed(className: "X", properties: ["a", "b"])
        let b = AMF3Traits.sealed(className: "X", properties: ["b", "a"])
        #expect(a != b)
    }

    @Test("isExternalizable default is false")
    func externalizableDefault() {
        let traits = AMF3Traits()
        #expect(traits.isExternalizable == false)
    }

    @Test("Dynamic with sealed properties is valid")
    func dynamicWithSealedProps() {
        let traits = AMF3Traits(
            className: "Mixed",
            isDynamic: true,
            properties: ["fixed1", "fixed2"]
        )
        #expect(traits.isDynamic == true)
        #expect(traits.properties.count == 2)
    }
}
