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
        #expect(mock.didConnect)
    }

    @Test("connect records host, port, useTLS")
    func connectRecordsParams() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "stream.example.com", port: 443, useTLS: true)
        #expect(mock.connectHost == "stream.example.com")
        #expect(mock.connectPort == 443)
        #expect(mock.connectUseTLS == true)
    }

    @Test("send records bytes")
    func sendRecordsBytes() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        try await mock.send([0x01, 0x02, 0x03])
        #expect(mock.sentBytes.count == 1)
        #expect(mock.sentBytes[0] == [0x01, 0x02, 0x03])
    }

    @Test("multiple sends accumulate in sentBytes")
    func multipleSends() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        try await mock.send([0x01])
        try await mock.send([0x02])
        try await mock.send([0x03])
        #expect(mock.sentBytes.count == 3)
    }

    @Test("receive returns scripted messages in order")
    func receiveScriptedMessages() async throws {
        let mock = MockTransport()
        let msg1 = RTMPMessage(typeID: 1, streamID: 0, timestamp: 0, payload: [0x01])
        let msg2 = RTMPMessage(typeID: 2, streamID: 0, timestamp: 0, payload: [0x02])
        mock.scriptedMessages = [msg1, msg2]
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
        #expect(mock.didClose)
    }

    @Test("isConnected reflects state")
    func isConnectedReflectsState() async throws {
        let mock = MockTransport()
        #expect(!mock.isConnected)
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        #expect(mock.isConnected)
        try await mock.close()
        #expect(!mock.isConnected)
    }

    @Test("nextError causes send to throw")
    func nextErrorSendThrows() async throws {
        let mock = MockTransport()
        try await mock.connect(host: "localhost", port: 1935, useTLS: false)
        mock.nextError = TransportError.connectionClosed
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
        mock.nextError = TransportError.connectionClosed
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
        mock.nextError = TransportError.connectionTimeout
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
        mock.reset()
        #expect(!mock.didConnect)
        #expect(!mock.didClose)
        #expect(mock.sentBytes.isEmpty)
        #expect(mock.scriptedMessages.isEmpty)
        #expect(mock.connectHost == nil)
    }
}
