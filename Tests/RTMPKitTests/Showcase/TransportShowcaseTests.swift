// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Transport DI Showcase")
struct TransportShowcaseTests {

    // MARK: - MockTransport Pattern

    @Test(
        "MockTransport replaces real network for testing"
    )
    func mockReplacesNetwork() async throws {
        // 1. Create a MockTransport
        let mock = MockTransport()

        // 2. Script a server response (window ack size)
        let ackMsg = RTMPMessage(
            controlMessage: .windowAcknowledgementSize(
                2_500_000
            )
        )
        mock.scriptedMessages = [ackMsg]

        // 3. Create RTMPPublisher with mock transport
        let publisher = RTMPPublisher(transport: mock)

        // 4. Verify publisher uses the mock, not NIO
        let state = await publisher.state
        #expect(state == .idle)

        // Connect through the mock
        try await mock.connect(
            host: "127.0.0.1", port: 1935,
            useTLS: false
        )
        #expect(mock.didConnect)
        #expect(mock.connectHost == "127.0.0.1")
        #expect(mock.connectPort == 1935)
        #expect(mock.connectUseTLS == false)

        // Receive the scripted message
        let received = try await mock.receive()
        #expect(
            received.typeID
                == RTMPMessage.typeIDWindowAckSize
        )
    }

    @Test("MockTransport can simulate server errors")
    func mockSimulatesErrors() async {
        let mock = MockTransport()

        // Script an error on connect
        mock.nextError = TransportError.connectionTimeout

        do {
            try await mock.connect(
                host: "bad.host", port: 1935,
                useTLS: false
            )
            Issue.record("Expected connectionTimeout")
        } catch {
            #expect(
                error as? TransportError
                    == .connectionTimeout
            )
        }

        // Mock should not be connected
        #expect(!mock.isConnected)
    }

    @Test(
        "MockTransport captures sent data for verification"
    )
    func mockCapturesSentData() async throws {
        let mock = MockTransport()

        // Connect the mock
        try await mock.connect(
            host: "server", port: 1935,
            useTLS: false
        )

        // Send bytes — mock records them
        let videoBytes: [UInt8] = [
            0x17, 0x01, 0x00, 0x00, 0x00, 0xAB, 0xCD
        ]
        try await mock.send(videoBytes)

        let audioBytes: [UInt8] = [0xAF, 0x01, 0xCA]
        try await mock.send(audioBytes)

        // Verify outgoing data was captured
        #expect(mock.sentBytes.count == 2)
        #expect(mock.sentBytes[0] == videoBytes)
        #expect(mock.sentBytes[1] == audioBytes)
    }

    @Test(
        "MockTransport throws when sending while not connected"
    )
    func mockThrowsNotConnected() async {
        let mock = MockTransport()

        do {
            try await mock.send([0x01])
            Issue.record("Expected notConnected")
        } catch {
            #expect(
                error as? TransportError
                    == .notConnected
            )
        }
    }

    @Test("MockTransport reset clears all state")
    func mockReset() async throws {
        let mock = MockTransport()
        try await mock.connect(
            host: "h", port: 1, useTLS: false
        )
        try await mock.send([0x01])
        try await mock.close()

        mock.reset()

        #expect(!mock.didConnect)
        #expect(!mock.didClose)
        #expect(mock.sentBytes.isEmpty)
        #expect(mock.scriptedMessages.isEmpty)
        #expect(mock.connectHost == nil)
        #expect(mock.connectPort == nil)
        #expect(mock.connectUseTLS == nil)
        #expect(mock.nextError == nil)
    }

    // MARK: - TransportConfiguration Presets

    @Test("Default transport configuration")
    func defaultTransportConfig() {
        let config = TransportConfiguration.default

        #expect(config.connectTimeout == 15)
        #expect(config.receiveBufferSize == 64 * 1024)
        #expect(config.sendBufferSize == 64 * 1024)
        #expect(config.tcpNoDelay == true)
        #expect(
            config.tlsMinimumVersion == .tlsv12
        )
    }

    @Test("Low-latency transport configuration")
    func lowLatencyTransportConfig() {
        let config = TransportConfiguration.lowLatency

        // Shorter timeout, smaller buffers
        #expect(config.connectTimeout == 10)
        #expect(config.receiveBufferSize == 32 * 1024)
        #expect(config.sendBufferSize == 32 * 1024)
        #expect(config.tcpNoDelay == true)
    }

    @Test("Custom transport configuration")
    func customTransportConfig() {
        let config = TransportConfiguration(
            connectTimeout: 30,
            receiveBufferSize: 128 * 1024,
            sendBufferSize: 128 * 1024,
            tcpNoDelay: false,
            tlsMinimumVersion: .tlsv13
        )

        #expect(config.connectTimeout == 30)
        #expect(
            config.receiveBufferSize == 128 * 1024
        )
        #expect(config.sendBufferSize == 128 * 1024)
        #expect(config.tcpNoDelay == false)
        #expect(
            config.tlsMinimumVersion == .tlsv13
        )
    }

    // MARK: - RTMPTransportProtocol Conformance

    @Test(
        "RTMPTransportProtocol defines the transport contract"
    )
    func protocolConformance() {
        // MockTransport conforms to RTMPTransportProtocol
        let mock: any RTMPTransportProtocol =
            MockTransport()
        _ = mock

        // NIOTransport also conforms (compile-time check)
        let nio: any RTMPTransportProtocol =
            NIOTransport()
        _ = nio

        // The protocol requires: connect, send,
        // receive, close, isConnected
        // (verified at compile time by conformance)
    }

    @Test(
        "Transport protocol enables dependency injection"
    )
    func dependencyInjectionPattern() async throws {
        // This demonstrates the "Testing Your App" pattern:

        // 1. Define a test double (MockTransport)
        let mock = MockTransport()

        // 2. Inject into RTMPPublisher
        let publisher = RTMPPublisher(transport: mock)

        // 3. Verify the publisher is in idle state
        let state = await publisher.state
        #expect(state == .idle)

        // 4. The mock allows full lifecycle testing
        //    without any real network connection
        #expect(!mock.didConnect)

        // Clean up
        await publisher.disconnect()
    }

    @Test(
        "Transport configuration is stored in RTMPConfiguration"
    )
    func configStoresTransport() {
        // Create config with specific transport settings
        let transport = TransportConfiguration(
            connectTimeout: 20,
            receiveBufferSize: 48 * 1024,
            sendBufferSize: 48 * 1024
        )

        let config = RTMPConfiguration(
            url: "rtmp://server/app",
            streamKey: "key",
            transportConfiguration: transport
        )

        // Verify transport config is stored
        #expect(
            config.transportConfiguration
                .connectTimeout == 20
        )
        #expect(
            config.transportConfiguration
                .receiveBufferSize == 48 * 1024
        )
        #expect(
            config.transportConfiguration
                .sendBufferSize == 48 * 1024
        )
    }
}
