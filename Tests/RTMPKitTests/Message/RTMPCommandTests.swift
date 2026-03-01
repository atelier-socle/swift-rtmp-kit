// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPCommand — Encoding")
struct RTMPCommandEncodeTests {

    @Test("connect encodes with correct AMF0 sequence")
    func encodeConnect() throws {
        let props = ConnectProperties(app: "live", tcUrl: "rtmp://localhost/live")
        let cmd = RTMPCommand.connect(transactionID: 1.0, properties: props)
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values.count == 3)
        #expect(values[0] == .string("connect"))
        #expect(values[1] == .number(1.0))
        #expect(values[2].objectProperties != nil)
    }

    @Test("createStream encodes correctly")
    func encodeCreateStream() throws {
        let cmd = RTMPCommand.createStream(transactionID: 2.0)
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values.count == 3)
        #expect(values[0] == .string("createStream"))
        #expect(values[1] == .number(2.0))
        #expect(values[2] == .null)
    }

    @Test("publish encodes correctly")
    func encodePublish() throws {
        let cmd = RTMPCommand.publish(
            transactionID: 3.0, streamName: "mystream", publishType: "live"
        )
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values.count == 5)
        #expect(values[0] == .string("publish"))
        #expect(values[1] == .number(3.0))
        #expect(values[2] == .null)
        #expect(values[3] == .string("mystream"))
        #expect(values[4] == .string("live"))
    }

    @Test("releaseStream encodes correctly")
    func encodeReleaseStream() throws {
        let cmd = RTMPCommand.releaseStream(transactionID: 2.0, streamName: "test")
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values[0] == .string("releaseStream"))
        #expect(values[3] == .string("test"))
    }

    @Test("FCPublish encodes correctly")
    func encodeFCPublish() throws {
        let cmd = RTMPCommand.fcPublish(transactionID: 2.0, streamName: "test")
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values[0] == .string("FCPublish"))
        #expect(values[3] == .string("test"))
    }

    @Test("FCUnpublish encodes correctly")
    func encodeFCUnpublish() throws {
        let cmd = RTMPCommand.fcUnpublish(transactionID: 2.0, streamName: "test")
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values[0] == .string("FCUnpublish"))
    }

    @Test("deleteStream encodes stream ID as number")
    func encodeDeleteStream() throws {
        let cmd = RTMPCommand.deleteStream(transactionID: 3.0, streamID: 1.0)
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values[0] == .string("deleteStream"))
        #expect(values[3] == .number(1.0))
    }

    @Test("onStatus encodes correctly")
    func encodeOnStatus() throws {
        let info = AMF0Value.object([
            ("level", .string("status")),
            ("code", .string("NetStream.Publish.Start"))
        ])
        let cmd = RTMPCommand.onStatus(information: info)
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values[0] == .string("onStatus"))
        #expect(values[1] == .number(0))
        #expect(values[2] == .null)
    }

    @Test("_result encodes correctly")
    func encodeResult() throws {
        let cmd = RTMPCommand.result(
            transactionID: 1.0,
            properties: .object([("fmsVer", .string("FMS/3,5"))]),
            information: .object([("code", .string("NetConnection.Connect.Success"))])
        )
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values[0] == .string("_result"))
        #expect(values[1] == .number(1.0))
    }

    @Test("_error encodes correctly")
    func encodeError() throws {
        let cmd = RTMPCommand.error(
            transactionID: 1.0, properties: nil, information: .null
        )
        let bytes = cmd.encode()
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        #expect(values[0] == .string("_error"))
        #expect(values[2] == .null)
    }
}

@Suite("RTMPCommand — Decoding")
struct RTMPCommandDecodeTests {

    @Test("Decode connect")
    func decodeConnect() throws {
        let props = ConnectProperties(app: "live", tcUrl: "rtmp://localhost/live")
        let original = RTMPCommand.connect(transactionID: 1.0, properties: props)
        let decoded = try RTMPCommand.decode(from: original.encode())
        if case .connect(let txnID, let decodedProps) = decoded {
            #expect(txnID == 1.0)
            #expect(decodedProps.app == "live")
            #expect(decodedProps.tcUrl == "rtmp://localhost/live")
        } else {
            Issue.record("Expected connect command")
        }
    }

    @Test("Decode _result with connect success")
    func decodeResult() throws {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            .string("_result"),
            .number(1.0),
            .object([("fmsVer", .string("FMS/3,5"))]),
            .object([("code", .string("NetConnection.Connect.Success"))])
        ])
        let cmd = try RTMPCommand.decode(from: bytes)
        if case .result(let txnID, let props, let info) = cmd {
            #expect(txnID == 1.0)
            #expect(props != nil)
            #expect(info != nil)
        } else {
            Issue.record("Expected _result command")
        }
    }

    @Test("Decode _error")
    func decodeError() throws {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            .string("_error"),
            .number(1.0),
            .null,
            .object([("code", .string("NetConnection.Connect.Rejected"))])
        ])
        let cmd = try RTMPCommand.decode(from: bytes)
        if case .error(let txnID, let props, let info) = cmd {
            #expect(txnID == 1.0)
            #expect(props == nil)  // null becomes nil
            #expect(info != nil)
        } else {
            Issue.record("Expected _error command")
        }
    }

    @Test("Decode onStatus with NetStream.Publish.Start")
    func decodeOnStatus() throws {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            .string("onStatus"),
            .number(0),
            .null,
            .object([
                ("level", .string("status")),
                ("code", .string("NetStream.Publish.Start"))
            ])
        ])
        let cmd = try RTMPCommand.decode(from: bytes)
        if case .onStatus(let info) = cmd {
            #expect(info.objectProperties != nil)
        } else {
            Issue.record("Expected onStatus command")
        }
    }

    @Test("Decode createStream _result")
    func decodeCreateStreamResult() throws {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            .string("_result"),
            .number(2.0),
            .null,
            .number(1.0)
        ])
        let cmd = try RTMPCommand.decode(from: bytes)
        if case .result(let txnID, _, let info) = cmd {
            #expect(txnID == 2.0)
            #expect(info?.numberValue == 1.0)
        } else {
            Issue.record("Expected _result command")
        }
    }

    @Test("Decode unknown command throws")
    func decodeUnknownCommand() {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            .string("unknownCmd"),
            .number(1.0)
        ])
        #expect(throws: MessageError.self) {
            try RTMPCommand.decode(from: bytes)
        }
    }

    @Test("Decode empty bytes throws")
    func decodeEmptyBytes() {
        #expect(throws: (any Error).self) {
            try RTMPCommand.decode(from: [])
        }
    }
}

@Suite("RTMPCommand — Roundtrip")
struct RTMPCommandRoundtripTests {

    @Test("Roundtrip connect")
    func roundtripConnect() throws {
        let props = ConnectProperties(app: "live", tcUrl: "rtmp://localhost/live")
        let original = RTMPCommand.connect(transactionID: 1.0, properties: props)
        let decoded = try RTMPCommand.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip createStream")
    func roundtripCreateStream() throws {
        let original = RTMPCommand.createStream(transactionID: 4.0)
        let decoded = try RTMPCommand.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip publish")
    func roundtripPublish() throws {
        let original = RTMPCommand.publish(
            transactionID: 5.0, streamName: "live_stream", publishType: "live"
        )
        let decoded = try RTMPCommand.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip releaseStream")
    func roundtripReleaseStream() throws {
        let original = RTMPCommand.releaseStream(transactionID: 2.0, streamName: "test")
        let decoded = try RTMPCommand.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip FCPublish")
    func roundtripFCPublish() throws {
        let original = RTMPCommand.fcPublish(transactionID: 2.0, streamName: "test")
        let decoded = try RTMPCommand.decode(from: original.encode())
        #expect(decoded == original)
    }

    @Test("Roundtrip deleteStream")
    func roundtripDeleteStream() throws {
        let original = RTMPCommand.deleteStream(transactionID: 3.0, streamID: 1.0)
        let decoded = try RTMPCommand.decode(from: original.encode())
        #expect(decoded == original)
    }
}

@Suite("ConnectProperties")
struct ConnectPropertiesTests {

    @Test("Default values are correct")
    func defaultValues() {
        let props = ConnectProperties(app: "live", tcUrl: "rtmp://localhost/live")
        #expect(props.flashVer == "FMLE/3.0 (compatible; FMSc/1.0)")
        #expect(props.type == "nonprivate")
        #expect(props.fpad == false)
        #expect(props.capabilities == 15)
        #expect(props.audioCodecs == 0x0FFF)
        #expect(props.videoCodecs == 0x00FF)
        #expect(props.videoFunction == 1)
        #expect(props.objectEncoding == 0)
    }

    @Test("toAMF0 preserves property order")
    func propertyOrder() {
        let props = ConnectProperties(app: "live", tcUrl: "rtmp://localhost/live")
        let amf0 = props.toAMF0()
        guard let pairs = amf0.objectProperties else {
            Issue.record("Expected object")
            return
        }
        #expect(pairs[0].0 == "app")
        #expect(pairs[1].0 == "flashVer")
        #expect(pairs[2].0 == "tcUrl")
        #expect(pairs[3].0 == "type")
        #expect(pairs[4].0 == "fpad")
        #expect(pairs[5].0 == "capabilities")
        #expect(pairs[6].0 == "audioCodecs")
        #expect(pairs[7].0 == "videoCodecs")
        #expect(pairs[8].0 == "videoFunction")
        #expect(pairs[9].0 == "objectEncoding")
    }

    @Test("Custom additional properties included")
    func additionalProperties() {
        var props = ConnectProperties(app: "live", tcUrl: "rtmp://localhost/live")
        props.additional.append(("customKey", .string("customValue")))
        let amf0 = props.toAMF0()
        guard let pairs = amf0.objectProperties else {
            Issue.record("Expected object")
            return
        }
        #expect(pairs.count == 11)
        #expect(pairs[10].0 == "customKey")
        #expect(pairs[10].1 == .string("customValue"))
    }

    @Test("fromAMF0 parses all properties")
    func fromAMF0() {
        let props = ConnectProperties(
            app: "myapp",
            flashVer: "test/1.0",
            tcUrl: "rtmp://host/myapp",
            fpad: true,
            capabilities: 31,
            audioCodecs: 1024,
            videoCodecs: 128
        )
        let amf0 = props.toAMF0()
        let parsed = ConnectProperties.fromAMF0(amf0)
        #expect(parsed.app == "myapp")
        #expect(parsed.flashVer == "test/1.0")
        #expect(parsed.tcUrl == "rtmp://host/myapp")
        #expect(parsed.fpad == true)
        #expect(parsed.capabilities == 31)
        #expect(parsed.audioCodecs == 1024)
        #expect(parsed.videoCodecs == 128)
    }

    @Test("fromAMF0 with null returns defaults")
    func fromAMF0Null() {
        let props = ConnectProperties.fromAMF0(.null)
        #expect(props.app == "")
        #expect(props.tcUrl == "")
    }

    @Test("Roundtrip encode-decode")
    func roundtrip() {
        let props = ConnectProperties(
            app: "live",
            tcUrl: "rtmp://localhost/live"
        )
        let amf0 = props.toAMF0()
        let parsed = ConnectProperties.fromAMF0(amf0)
        #expect(parsed == props)
    }
}
