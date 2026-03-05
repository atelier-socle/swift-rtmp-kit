// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("CuePoint")
struct CuePointTests {

    @Test("Init with defaults")
    func initDefaults() {
        let cp = CuePoint(name: "marker", time: 1500)
        #expect(cp.name == "marker")
        #expect(cp.time == 1500)
        #expect(cp.type == .navigation)
        #expect(cp.parameters.isEmpty)
    }

    @Test("Init with event type and parameters")
    func initWithParams() {
        let cp = CuePoint(
            name: "ad-break",
            time: 30000,
            type: .event,
            parameters: ["duration": .number(15)]
        )
        #expect(cp.name == "ad-break")
        #expect(cp.type == .event)
        #expect(cp.parameters["duration"] == .number(15))
    }

    @Test("toAMF0Object contains name, time, type")
    func toAMF0ObjectBasic() {
        let cp = CuePoint(name: "chapter1", time: 5000, type: .navigation)
        let amf0 = cp.toAMF0Object()
        guard let props = amf0.objectProperties else {
            Issue.record("Expected object")
            return
        }
        let dict = Dictionary(props, uniquingKeysWith: { _, b in b })
        #expect(dict["name"] == .string("chapter1"))
        #expect(dict["time"] == .number(5000))
        #expect(dict["type"] == .string("navigation"))
    }

    @Test("toAMF0Object includes parameters")
    func toAMF0ObjectWithParams() {
        let cp = CuePoint(
            name: "ad",
            time: 60000,
            type: .event,
            parameters: ["sponsor": .string("acme")]
        )
        let amf0 = cp.toAMF0Object()
        guard let props = amf0.objectProperties else {
            Issue.record("Expected object")
            return
        }
        let dict = Dictionary(props, uniquingKeysWith: { _, b in b })
        #expect(dict["sponsor"] == .string("acme"))
    }

    @Test("CuePointType raw values")
    func cuePointTypeRawValues() {
        #expect(CuePoint.CuePointType.navigation.rawValue == "navigation")
        #expect(CuePoint.CuePointType.event.rawValue == "event")
    }

    @Test("CuePointType CaseIterable")
    func cuePointTypeCaseIterable() {
        #expect(CuePoint.CuePointType.allCases.count == 2)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = CuePoint(name: "test", time: 100)
        let b = CuePoint(name: "test", time: 100)
        let c = CuePoint(name: "other", time: 200)
        #expect(a == b)
        #expect(a != c)
    }
}
