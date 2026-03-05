// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPCommand — Decode Error Paths")
struct RTMPCommandDecodeErrorCoverageTests {

    @Test("Missing transaction ID throws")
    func missingTransactionID() {
        // Only command name, no transaction ID
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([AMF0Value.string("connect")])
        #expect(throws: (any Error).self) {
            _ = try RTMPCommand.decode(from: bytes)
        }
    }

    @Test("connect missing properties throws")
    func connectMissingProperties() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            AMF0Value.string("connect"),
            AMF0Value.number(1)
        ])
        #expect(throws: (any Error).self) {
            _ = try RTMPCommand.decode(from: bytes)
        }
    }

    @Test("publish missing stream name throws")
    func publishMissingStreamName() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            AMF0Value.string("publish"),
            AMF0Value.number(0),
            AMF0Value.null
        ])
        #expect(throws: (any Error).self) {
            _ = try RTMPCommand.decode(from: bytes)
        }
    }

    @Test("releaseStream missing stream name throws")
    func releaseStreamMissingName() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            AMF0Value.string("releaseStream"),
            AMF0Value.number(0),
            AMF0Value.null
        ])
        #expect(throws: (any Error).self) {
            _ = try RTMPCommand.decode(from: bytes)
        }
    }

    @Test("deleteStream missing stream ID throws")
    func deleteStreamMissingID() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            AMF0Value.string("deleteStream"),
            AMF0Value.number(0),
            AMF0Value.null
        ])
        #expect(throws: (any Error).self) {
            _ = try RTMPCommand.decode(from: bytes)
        }
    }

    @Test("Unknown command name throws")
    func unknownCommandName() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            AMF0Value.string("unknownCmd"),
            AMF0Value.number(0),
            AMF0Value.null
        ])
        #expect(throws: (any Error).self) {
            _ = try RTMPCommand.decode(from: bytes)
        }
    }
}

@Suite("RTMPDataMessage — Decode Error Paths")
struct RTMPDataMessageDecodeErrorCoverageTests {

    @Test("setDataFrame without metadata throws")
    func setDataFrameWithoutMetadata() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            AMF0Value.string("@setDataFrame"),
            AMF0Value.string("onMetaData")
        ])
        #expect(throws: (any Error).self) {
            _ = try RTMPDataMessage.decode(from: bytes)
        }
    }
}
