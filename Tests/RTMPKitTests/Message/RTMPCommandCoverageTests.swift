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

    @Test(
        "Bandwidth commands decode as ignored",
        arguments: ["onBWDone", "onBWCheck", "_onbw", "_checkbw"]
    )
    func bandwidthCommandsIgnored(name: String) throws {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            AMF0Value.string(name),
            AMF0Value.number(0),
            AMF0Value.null
        ])
        let cmd = try RTMPCommand.decode(from: bytes)
        #expect(cmd == .ignored(name: name))
    }

    @Test("Ignored command roundtrips")
    func ignoredCommandRoundtrip() throws {
        let original = RTMPCommand.ignored(name: "onBWDone")
        let bytes = original.encode()
        let decoded = try RTMPCommand.decode(from: bytes)
        #expect(decoded == .ignored(name: "onBWDone"))
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
