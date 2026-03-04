// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPTransportProtocol — MockTransport")
struct RTMPTransportProtocolTests {

    @Test("connect sets didConnect")
    func connectSetsDidConnect() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        let connected = await mock.didConnect
        #expect(connected)
    }

    @Test("connect records host, port, useTLS")
    func connectRecordsParams() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "stream.example.com", port: 443, useTLS: true)
        let host = await mock.connectHost
        let port = await mock.connectPort
        let tls = await mock.connectUseTLS
        #expect(host == "stream.example.com")
        #expect(port == 443)
        #expect(tls == true)
    }

    @Test("send records bytes")
    func sendRecordsBytes() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        try await mock.send([0x01, 0x02, 0x03])
        let sent = await mock.sentBytes
        #expect(sent.count == 1)
        #expect(sent[0] == [0x01, 0x02, 0x03])
    }

    @Test("multiple sends accumulate in sentBytes")
    func multipleSends() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        try await mock.send([0x01])
        try await mock.send([0x02])
        try await mock.send([0x03])
        let count = await mock.sentBytes.count
        #expect(count == 3)
    }

    @Test("receive returns scripted messages in order")
    func receiveScriptedMessages() async throws {
        let mock = MockTransport()
        let msg1 = RTMPMessage(typeID: 1, streamID: 0, timestamp: 0, payload: [0x01])
        let msg2 = RTMPMessage(typeID: 2, streamID: 0, timestamp: 0, payload: [0x02])
        await mock.setScriptedMessages([msg1, msg2])
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        let r1 = try await mock.receive()
        let r2 = try await mock.receive()
        #expect(r1 == msg1)
        #expect(r2 == msg2)
    }

    @Test("close sets didClose")
    func closeSetsDidClose() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        try await mock.close()
        let closed = await mock.didClose
        #expect(closed)
    }

    @Test("isConnected reflects state")
    func isConnectedReflectsState() async throws {
        let mock = MockTransport()
        var connected = await mock.isConnected
        #expect(!connected)
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        connected = await mock.isConnected
        #expect(connected)
        try await mock.close()
        connected = await mock.isConnected
        #expect(!connected)
    }

    @Test("nextError causes send to throw")
    func nextErrorSendThrows() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        await mock.setNextError(TransportError.connectionClosed)
        do {
            try await mock.send([0x01])
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("nextError causes receive to throw")
    func nextErrorReceiveThrows() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        await mock.setNextError(TransportError.connectionClosed)
        do {
            _ = try await mock.receive()
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("receive throws when no scripted messages")
    func receiveEmptyThrows() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        do {
            _ = try await mock.receive()
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("send when disconnected throws")
    func sendDisconnectedThrows() async {
        let mock = MockTransport()
        do {
            try await mock.send([0x01])
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("nextError causes connect to throw")
    func nextErrorConnectThrows() async {
        let mock = MockTransport()
        await mock.setNextError(TransportError.connectionTimeout)
        do {
            try await mock.connect(host: "localhost", port: 1935, useTLS: false)
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("reset clears all state")
    func resetClearsState() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        try await mock.send([0x01])
        await mock.reset()
        let connected = await mock.didConnect
        let closed = await mock.didClose
        let sent = await mock.sentBytes
        let scripted = await mock.scriptedMessages
        let host = await mock.connectHost
        #expect(!connected)
        #expect(!closed)
        #expect(sent.isEmpty)
        #expect(scripted.isEmpty)
        #expect(host == nil)
    }
}
