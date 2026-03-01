// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPMessage — Type ID Constants")
struct RTMPMessageTypeIDTests {

    @Test("Well-known type ID constants")
    func typeIDConstants() {
        #expect(RTMPMessage.typeIDSetChunkSize == 1)
        #expect(RTMPMessage.typeIDAbort == 2)
        #expect(RTMPMessage.typeIDAcknowledgement == 3)
        #expect(RTMPMessage.typeIDUserControl == 4)
        #expect(RTMPMessage.typeIDWindowAckSize == 5)
        #expect(RTMPMessage.typeIDSetPeerBandwidth == 6)
        #expect(RTMPMessage.typeIDAudio == 8)
        #expect(RTMPMessage.typeIDVideo == 9)
        #expect(RTMPMessage.typeIDDataAMF0 == 18)
        #expect(RTMPMessage.typeIDCommandAMF0 == 20)
    }
}

@Suite("RTMPMessage — Convenience Initializers")
struct RTMPMessageConvenienceTests {

    // MARK: - Command

    @Test("init(command:) sets typeID 20")
    func commandTypeID() {
        let cmd = RTMPCommand.createStream(transactionID: 2.0)
        let msg = RTMPMessage(command: cmd)
        #expect(msg.typeID == 20)
    }

    @Test("init(command:) defaults streamID to 0")
    func commandDefaultStreamID() {
        let cmd = RTMPCommand.createStream(transactionID: 2.0)
        let msg = RTMPMessage(command: cmd)
        #expect(msg.streamID == 0)
    }

    @Test("init(command:) accepts custom streamID")
    func commandCustomStreamID() {
        let cmd = RTMPCommand.publish(
            transactionID: 3.0, streamName: "live", publishType: "live"
        )
        let msg = RTMPMessage(command: cmd, streamID: 1)
        #expect(msg.streamID == 1)
    }

    @Test("init(command:) defaults timestamp to 0")
    func commandDefaultTimestamp() {
        let cmd = RTMPCommand.createStream(transactionID: 2.0)
        let msg = RTMPMessage(command: cmd)
        #expect(msg.timestamp == 0)
    }

    @Test("init(command:) payload matches encode()")
    func commandPayloadMatchesEncode() {
        let cmd = RTMPCommand.createStream(transactionID: 2.0)
        let msg = RTMPMessage(command: cmd)
        #expect(msg.payload == cmd.encode())
    }

    @Test("init(command:) with connect")
    func commandConnect() {
        let props = ConnectProperties(app: "live", tcUrl: "rtmp://localhost/live")
        let cmd = RTMPCommand.connect(transactionID: 1.0, properties: props)
        let msg = RTMPMessage(command: cmd, timestamp: 100)
        #expect(msg.typeID == RTMPMessage.typeIDCommandAMF0)
        #expect(msg.timestamp == 100)
        #expect(msg.payload == cmd.encode())
    }

    // MARK: - Control Message

    @Test("init(controlMessage:) uses controlMessage.typeID")
    func controlMessageTypeID() {
        let ctrl = RTMPControlMessage.setChunkSize(4096)
        let msg = RTMPMessage(controlMessage: ctrl)
        #expect(msg.typeID == 1)
    }

    @Test("init(controlMessage:) always sets streamID 0")
    func controlMessageStreamIDZero() {
        let ctrl = RTMPControlMessage.windowAcknowledgementSize(2_500_000)
        let msg = RTMPMessage(controlMessage: ctrl)
        #expect(msg.streamID == 0)
    }

    @Test("init(controlMessage:) payload matches encode()")
    func controlMessagePayload() {
        let ctrl = RTMPControlMessage.setChunkSize(4096)
        let msg = RTMPMessage(controlMessage: ctrl)
        #expect(msg.payload == ctrl.encode())
    }

    @Test("init(controlMessage:) each type ID is correct")
    func controlMessageAllTypeIDs() {
        #expect(RTMPMessage(controlMessage: .setChunkSize(128)).typeID == 1)
        #expect(RTMPMessage(controlMessage: .abort(chunkStreamID: 3)).typeID == 2)
        #expect(
            RTMPMessage(controlMessage: .acknowledgement(sequenceNumber: 0)).typeID == 3
        )
        #expect(
            RTMPMessage(controlMessage: .windowAcknowledgementSize(0)).typeID == 5
        )
        #expect(
            RTMPMessage(
                controlMessage: .setPeerBandwidth(windowSize: 0, limitType: .hard)
            ).typeID == 6
        )
    }

    @Test("init(controlMessage:) accepts timestamp")
    func controlMessageTimestamp() {
        let ctrl = RTMPControlMessage.setChunkSize(4096)
        let msg = RTMPMessage(controlMessage: ctrl, timestamp: 500)
        #expect(msg.timestamp == 500)
    }

    // MARK: - User Control Event

    @Test("init(userControlEvent:) sets typeID 4")
    func userControlTypeID() {
        let event = RTMPUserControlEvent.streamBegin(streamID: 1)
        let msg = RTMPMessage(userControlEvent: event)
        #expect(msg.typeID == 4)
    }

    @Test("init(userControlEvent:) always sets streamID 0")
    func userControlStreamIDZero() {
        let event = RTMPUserControlEvent.pingResponse(timestamp: 12345)
        let msg = RTMPMessage(userControlEvent: event)
        #expect(msg.streamID == 0)
    }

    @Test("init(userControlEvent:) payload matches encode()")
    func userControlPayload() {
        let event = RTMPUserControlEvent.setBufferLength(
            streamID: 1, bufferLengthMs: 3000
        )
        let msg = RTMPMessage(userControlEvent: event)
        #expect(msg.payload == event.encode())
    }

    @Test("init(userControlEvent:) accepts timestamp")
    func userControlTimestamp() {
        let event = RTMPUserControlEvent.streamBegin(streamID: 1)
        let msg = RTMPMessage(userControlEvent: event, timestamp: 200)
        #expect(msg.timestamp == 200)
    }

    // MARK: - Data Message

    @Test("init(dataMessage:) sets typeID 18")
    func dataMessageTypeID() {
        var meta = StreamMetadata()
        meta.width = 1920
        let data = RTMPDataMessage.setDataFrame(metadata: meta)
        let msg = RTMPMessage(dataMessage: data, streamID: 1)
        #expect(msg.typeID == 18)
    }

    @Test("init(dataMessage:) uses provided streamID")
    func dataMessageStreamID() {
        var meta = StreamMetadata()
        meta.width = 1920
        let data = RTMPDataMessage.setDataFrame(metadata: meta)
        let msg = RTMPMessage(dataMessage: data, streamID: 42)
        #expect(msg.streamID == 42)
    }

    @Test("init(dataMessage:) payload matches encode()")
    func dataMessagePayload() {
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        let data = RTMPDataMessage.setDataFrame(metadata: meta)
        let msg = RTMPMessage(dataMessage: data, streamID: 1)
        #expect(msg.payload == data.encode())
    }

    @Test("init(dataMessage:) defaults timestamp to 0")
    func dataMessageDefaultTimestamp() {
        let data = RTMPDataMessage.onMetaData(metadata: .null)
        let msg = RTMPMessage(dataMessage: data, streamID: 1)
        #expect(msg.timestamp == 0)
    }

    @Test("init(dataMessage:) accepts timestamp")
    func dataMessageTimestamp() {
        let data = RTMPDataMessage.onMetaData(metadata: .null)
        let msg = RTMPMessage(dataMessage: data, streamID: 1, timestamp: 300)
        #expect(msg.timestamp == 300)
    }
}
