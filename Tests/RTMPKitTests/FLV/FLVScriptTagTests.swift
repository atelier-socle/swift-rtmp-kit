// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("FLVScriptTag")
struct FLVScriptTagTests {

    // MARK: - Encode

    @Test("encode empty values produces empty bytes")
    func encodeEmpty() {
        let bytes = FLVScriptTag.encode(values: [])
        #expect(bytes.isEmpty)
    }

    @Test("encode single string value")
    func encodeSingleString() {
        let bytes = FLVScriptTag.encode(values: [.string("onMetaData")])
        #expect(!bytes.isEmpty)
    }

    @Test("encode multiple values")
    func encodeMultipleValues() {
        let bytes = FLVScriptTag.encode(values: [
            .string("onMetaData"),
            .number(1920)
        ])
        #expect(!bytes.isEmpty)
    }

    // MARK: - Decode

    @Test("decode roundtrip single value")
    func decodeRoundtripSingle() throws {
        let original: [AMF0Value] = [.string("onMetaData")]
        let bytes = FLVScriptTag.encode(values: original)
        let decoded = try FLVScriptTag.decode(from: bytes)
        #expect(decoded.count == 1)
        #expect(decoded[0] == .string("onMetaData"))
    }

    @Test("decode roundtrip multiple values")
    func decodeRoundtripMultiple() throws {
        let original: [AMF0Value] = [
            .string("@setDataFrame"),
            .string("onMetaData"),
            .number(30.0)
        ]
        let bytes = FLVScriptTag.encode(values: original)
        let decoded = try FLVScriptTag.decode(from: bytes)
        #expect(decoded.count == 3)
        #expect(decoded[0] == .string("@setDataFrame"))
        #expect(decoded[1] == .string("onMetaData"))
        #expect(decoded[2] == .number(30.0))
    }

    @Test("decode empty bytes produces empty array")
    func decodeEmptyBytes() throws {
        let decoded = try FLVScriptTag.decode(from: [])
        #expect(decoded.isEmpty)
    }

    // MARK: - Integration

    @Test("FLVScriptTag delegates to AMF0Encoder/Decoder")
    func delegatesToAMF0() throws {
        let values: [AMF0Value] = [.string("test"), .boolean(true), .null]
        let bytes = FLVScriptTag.encode(values: values)
        let decoded = try FLVScriptTag.decode(from: bytes)
        #expect(decoded.count == 3)
        #expect(decoded[0] == .string("test"))
        #expect(decoded[1] == .boolean(true))
        #expect(decoded[2] == .null)
    }

    @Test("encode with ecmaArray for metadata")
    func encodeWithEcmaArray() throws {
        let metadata = AMF0Value.ecmaArray([
            ("width", .number(1920)),
            ("height", .number(1080))
        ])
        let bytes = FLVScriptTag.encode(values: [.string("onMetaData"), metadata])
        let decoded = try FLVScriptTag.decode(from: bytes)
        #expect(decoded.count == 2)
        #expect(decoded[0] == .string("onMetaData"))
    }
}
