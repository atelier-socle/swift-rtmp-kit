// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - AMF3 Decoder Reference and Error Paths

@Suite("AMF3Decoder — Reference and Error Paths")
struct AMF3DecoderCoverageTests {

    @Test("reset clears all reference tables")
    func resetClearsTables() throws {
        var decoder = AMF3Decoder()
        // Decode a string to populate the string reference table
        let encoded: [UInt8] = [
            0x06,  // string marker
            0x0B,  // U29 length 5 (5<<1|1 = 11 = 0x0B)
            0x48, 0x65, 0x6C, 0x6C, 0x6F  // "Hello"
        ]
        _ = try decoder.decode(from: encoded)
        decoder.reset()
        // After reset, reference tables are cleared
        let refBytes: [UInt8] = [0x06, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: refBytes)
        }
    }

    @Test("invalid string reference index throws error")
    func invalidStringRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x06, 0x0A]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid array reference index throws error")
    func invalidArrayRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x09, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid object reference index throws error")
    func invalidObjectRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x0A, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("truncated input throws unexpectedEndOfData")
    func truncatedInputThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x06]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid XML reference throws error")
    func invalidXMLRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x0B, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid ByteArray reference throws error")
    func invalidByteArrayRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x0C, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid VectorInt reference throws error")
    func invalidVectorIntRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x0D, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid VectorUInt reference throws error")
    func invalidVectorUIntRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x0E, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid VectorDouble reference throws error")
    func invalidVectorDoubleRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x0F, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid VectorObject reference throws error")
    func invalidVectorObjectRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x10, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }

    @Test("invalid Dictionary reference throws error")
    func invalidDictionaryRefThrows() {
        var decoder = AMF3Decoder()
        let bytes: [UInt8] = [0x11, 0x00]
        #expect(throws: AMF3DecodingError.self) {
            _ = try decoder.decode(from: bytes)
        }
    }
}

// MARK: - AMF3 Encoder Reference Dedup

@Suite("AMF3Encoder — Reference Dedup Paths")
struct AMF3EncoderRefDedupTests {

    @Test("encoding same string twice uses reference table")
    func stringRefDedup() throws {
        var encoder = AMF3Encoder()
        let first = try encoder.encode(.string("hello"))
        let second = try encoder.encode(.string("hello"))
        // Second encoding should be shorter (just a reference index)
        #expect(second.count < first.count)
    }

    @Test("encoding same array twice uses reference table")
    func arrayRefDedup() throws {
        var encoder = AMF3Encoder()
        let arr = AMF3Value.array(
            dense: [.integer(1), .integer(2)], associative: [:]
        )
        let first = try encoder.encode(arr)
        let second = try encoder.encode(arr)
        #expect(second.count < first.count)
    }

    @Test("encoding same object twice uses reference table")
    func objectRefDedup() throws {
        var encoder = AMF3Encoder()
        let obj = AMF3Value.object(
            AMF3Object(
                traits: AMF3Traits(
                    className: "", isDynamic: true, isExternalizable: false,
                    properties: []
                ),
                dynamicProperties: ["key": .string("val")]
            ))
        let first = try encoder.encode(obj)
        let second = try encoder.encode(obj)
        #expect(second.count < first.count)
    }
}
