// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("EnhancedRTMP")
struct EnhancedRTMPTests {

    // MARK: - Defaults

    @Test("isEnabled default is false")
    func defaultDisabled() {
        let enhanced = EnhancedRTMP()
        #expect(!enhanced.isEnabled)
    }

    @Test("negotiatedCodecs default is empty")
    func defaultEmpty() {
        let enhanced = EnhancedRTMP()
        #expect(enhanced.negotiatedCodecs.isEmpty)
    }

    // MARK: - fourCcListAMF0

    @Test("fourCcListAMF0 produces strictArray of strings")
    func fourCcListAMF0() {
        let amf0 = EnhancedRTMP.fourCcListAMF0(codecs: [.hevc, .opus])
        guard let elements = amf0.arrayElements else {
            Issue.record("Expected strictArray")
            return
        }
        #expect(elements.count == 2)
        #expect(elements[0] == .string("hvc1"))
        #expect(elements[1] == .string("Opus"))
    }

    @Test("fourCcListAMF0 default list contains all expected codecs")
    func defaultList() {
        let amf0 = EnhancedRTMP.fourCcListAMF0(codecs: EnhancedRTMP.defaultFourCcList)
        guard let elements = amf0.arrayElements else {
            Issue.record("Expected strictArray")
            return
        }
        #expect(elements.count == 7)
    }

    @Test("fourCcListAMF0 empty list produces empty array")
    func emptyList() {
        let amf0 = EnhancedRTMP.fourCcListAMF0(codecs: [])
        guard let elements = amf0.arrayElements else {
            Issue.record("Expected strictArray")
            return
        }
        #expect(elements.isEmpty)
    }

    // MARK: - parseFourCcList

    @Test("parseFourCcList from strictArray")
    func parseFromStrictArray() {
        let amf0 = AMF0Value.strictArray([
            .string("hvc1"), .string("Opus")
        ])
        let codecs = EnhancedRTMP.parseFourCcList(from: amf0)
        #expect(codecs.count == 2)
        #expect(codecs[0] == .hevc)
        #expect(codecs[1] == .opus)
    }

    @Test("parseFourCcList from ecmaArray")
    func parseFromEcmaArray() {
        let amf0 = AMF0Value.ecmaArray([
            ("0", .string("hvc1")),
            ("1", .string("av01"))
        ])
        let codecs = EnhancedRTMP.parseFourCcList(from: amf0)
        #expect(codecs.count == 2)
        #expect(codecs[0] == .hevc)
        #expect(codecs[1] == .av1)
    }

    @Test("parseFourCcList empty → empty")
    func parseEmpty() {
        let codecs = EnhancedRTMP.parseFourCcList(from: .strictArray([]))
        #expect(codecs.isEmpty)
    }

    @Test("parseFourCcList null → empty")
    func parseNull() {
        let codecs = EnhancedRTMP.parseFourCcList(from: .null)
        #expect(codecs.isEmpty)
    }

    @Test("parseFourCcList skips non-4-char strings")
    func parseSkipsInvalid() {
        let amf0 = AMF0Value.strictArray([
            .string("hvc1"), .string("ab"), .string("av01")
        ])
        let codecs = EnhancedRTMP.parseFourCcList(from: amf0)
        #expect(codecs.count == 2)
    }

    // MARK: - supports

    @Test("supports returns true for negotiated codec")
    func supportsNegotiated() {
        let enhanced = EnhancedRTMP(isEnabled: true, negotiatedCodecs: [.hevc, .opus])
        #expect(enhanced.supports(.hevc))
        #expect(enhanced.supports(.opus))
    }

    @Test("supports returns false for non-negotiated codec")
    func supportsNotNegotiated() {
        let enhanced = EnhancedRTMP(isEnabled: true, negotiatedCodecs: [.hevc])
        #expect(!enhanced.supports(.av1))
        #expect(!enhanced.supports(.opus))
    }

    // MARK: - Full Negotiation Flow

    @Test("Full negotiation: build list → parse response → check supports")
    func fullNegotiation() {
        // Client builds fourCcList
        let clientList = EnhancedRTMP.fourCcListAMF0(codecs: [.hevc, .av1, .opus])
        // Server responds with subset
        let serverResponse = AMF0Value.strictArray([
            .string("hvc1"), .string("Opus")
        ])
        let negotiated = EnhancedRTMP.parseFourCcList(from: serverResponse)
        let enhanced = EnhancedRTMP(isEnabled: true, negotiatedCodecs: negotiated)
        #expect(enhanced.supports(.hevc))
        #expect(enhanced.supports(.opus))
        #expect(!enhanced.supports(.av1))
        // Verify client list was valid
        #expect(clientList.arrayElements?.count == 3)
    }

    @Test("defaultFourCcList contains 7 codecs")
    func defaultFourCcListCount() {
        #expect(EnhancedRTMP.defaultFourCcList.count == 7)
    }
}
