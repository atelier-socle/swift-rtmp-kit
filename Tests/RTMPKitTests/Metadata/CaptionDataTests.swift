// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("CaptionData")
struct CaptionDataTests {

    @Test("Init with defaults")
    func initDefaults() {
        let cd = CaptionData(text: "Hello world", timestamp: 5000)
        #expect(cd.standard == .cea708)
        #expect(cd.text == "Hello world")
        #expect(cd.language == "en")
        #expect(cd.timestamp == 5000)
    }

    @Test("Init with custom standard and language")
    func initCustom() {
        let cd = CaptionData(
            standard: .cea608, text: "Bonjour",
            language: "fr", timestamp: 10000
        )
        #expect(cd.standard == .cea608)
        #expect(cd.language == "fr")
    }

    @Test("toAMF0Object contains all fields")
    func toAMF0Object() {
        let cd = CaptionData(
            standard: .text, text: "Subtitle",
            language: "ja", timestamp: 15000
        )
        let amf0 = cd.toAMF0Object()
        guard let props = amf0.objectProperties else {
            Issue.record("Expected object")
            return
        }
        let dict = Dictionary(props, uniquingKeysWith: { _, b in b })
        #expect(dict["standard"] == .string("TEXT"))
        #expect(dict["text"] == .string("Subtitle"))
        #expect(dict["language"] == .string("ja"))
        #expect(dict["timestamp"] == .number(15000))
    }

    @Test("CaptionStandard raw values")
    func standardRawValues() {
        #expect(CaptionData.CaptionStandard.cea608.rawValue == "CEA-608")
        #expect(CaptionData.CaptionStandard.cea708.rawValue == "CEA-708")
        #expect(CaptionData.CaptionStandard.text.rawValue == "TEXT")
    }

    @Test("CaptionStandard CaseIterable")
    func standardCaseIterable() {
        #expect(CaptionData.CaptionStandard.allCases.count == 3)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = CaptionData(text: "test", timestamp: 100)
        let b = CaptionData(text: "test", timestamp: 100)
        let c = CaptionData(text: "other", timestamp: 200)
        #expect(a == b)
        #expect(a != c)
    }
}
