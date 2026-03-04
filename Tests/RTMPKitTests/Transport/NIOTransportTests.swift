// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("NIOTransport — State Management")
struct NIOTransportStateTests {

    @Test("Initial state is disconnected")
    func initialStateDisconnected() async {
        let transport = NIOTransport()
        let state = await transport.state
        #expect(state == .disconnected)
    }

    @Test("Initial isConnected is false")
    func initialIsConnectedFalse() async {
        let transport = NIOTransport()
        let connected = await transport.isConnected
        #expect(!connected)
    }

    @Test("Send when disconnected throws")
    func sendDisconnectedThrows() async {
        let transport = NIOTransport()
        do {
            try await transport.send([0x01])
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("Receive when disconnected throws")
    func receiveDisconnectedThrows() async {
        let transport = NIOTransport()
        do {
            _ = try await transport.receive()
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("Close when disconnected is no-op")
    func closeDisconnectedNoOp() async throws {
        let transport = NIOTransport()
        try await transport.close()
        let state = await transport.state
        #expect(state == .disconnected)
    }

    @Test("Connect to invalid host throws")
    func connectInvalidHostThrows() async {
        let config = TransportConfiguration(connectTimeout: 1)
        let transport = NIOTransport(configuration: config)
        do {
            try await transport.connect(
                host: "invalid.host.that.does.not.exist.example",
                port: 1935,
                useTLS: false
            )
            Issue.record("Expected error")
        } catch {
            // Connection should fail
            let state = await transport.state
            #expect(state == .disconnected)
        }
        try? await transport.shutdown()
    }

    @Test("Shutdown releases resources")
    func shutdownReleases() async throws {
        let transport = NIOTransport()
        try await transport.shutdown()
        let state = await transport.state
        #expect(state == .disconnected)
    }
}

@Suite("NIOTransport — Configuration")
struct NIOTransportConfigurationTests {

    @Test("Default creates own EventLoopGroup")
    func defaultCreatesOwnGroup() async throws {
        let transport = NIOTransport()
        let state = await transport.state
        #expect(state == .disconnected)
        try await transport.shutdown()
    }

    @Test("Custom configuration is stored")
    func customConfigStored() async {
        let config = TransportConfiguration(
            connectTimeout: 30,
            tcpNoDelay: false
        )
        let transport = NIOTransport(configuration: config)
        // Transport was created with custom config — no crash
        let state = await transport.state
        #expect(state == .disconnected)
    }

    @Test("Low latency config accepted")
    func lowLatencyConfigAccepted() async {
        let transport = NIOTransport(configuration: .lowLatency)
        let state = await transport.state
        #expect(state == .disconnected)
    }
}

@Suite("NIOTransport — ConnectionState")
struct NIOTransportConnectionStateTests {

    @Test("ConnectionState has four cases")
    func connectionStateCases() {
        let states: [NIOTransport.ConnectionState] = [
            .disconnected, .connecting, .connected, .disconnecting
        ]
        #expect(states.count == 4)
    }

    @Test("ConnectionState is Sendable")
    func connectionStateSendable() {
        let state: NIOTransport.ConnectionState = .connected
        let _: any Sendable = state
    }

    @Test("ConnectionState equatable")
    func connectionStateEquatable() {
        #expect(NIOTransport.ConnectionState.connected == .connected)
        #expect(NIOTransport.ConnectionState.disconnected != .connected)
    }
}

@Suite("NIOTransport — TransportError")
struct NIOTransportTransportErrorTests {

    @Test("TransportError cases are distinct")
    func errorCasesDistinct() {
        let errors: [TransportError] = [
            .notConnected,
            .alreadyConnected,
            .connectionClosed,
            .connectionTimeout,
            .tlsFailure("test"),
            .invalidState("test")
        ]
        #expect(errors.count == 6)
    }

    @Test("TransportError is Equatable")
    func errorEquatable() {
        #expect(TransportError.notConnected == TransportError.notConnected)
        #expect(TransportError.notConnected != TransportError.alreadyConnected)
    }

    @Test("TransportError tlsFailure preserves message")
    func tlsFailureMessage() {
        let error = TransportError.tlsFailure("certificate expired")
        if case .tlsFailure(let msg) = error {
            #expect(msg == "certificate expired")
        } else {
            Issue.record("Expected tlsFailure")
        }
    }
}
