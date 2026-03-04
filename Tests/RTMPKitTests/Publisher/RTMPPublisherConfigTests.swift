// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Test Helpers

/// Build a scripted server response sequence for a successful publish.
private func makePublishScript() -> [RTMPMessage] {
    [
        RTMPMessage(controlMessage: .windowAcknowledgementSize(2_500_000)),
        RTMPMessage(
            controlMessage: .setPeerBandwidth(
                windowSize: 2_500_000, limitType: .dynamic
            )
        ),
        RTMPMessage(
            command: .result(
                transactionID: 1,
                properties: nil,
                information: .object([
                    ("level", .string("status")),
                    ("code", .string("NetConnection.Connect.Success")),
                    ("description", .string("Connection succeeded"))
                ])
            )),
        RTMPMessage(
            command: .result(
                transactionID: 4,
                properties: nil,
                information: .number(1)
            )),
        RTMPMessage(
            command: .onStatus(
                information: .object([
                    ("level", .string("status")),
                    ("code", .string("NetStream.Publish.Start")),
                    ("description", .string("Publishing live_test"))
                ])))
    ]
}

/// Create a publisher with a scripted mock transport.
private func makeScriptedPublisher() async -> (RTMPPublisher, MockTransport) {
    let mock = MockTransport()
    await mock.setScriptedMessages(makePublishScript())
    let publisher = RTMPPublisher(transport: mock)
    return (publisher, mock)
}

// MARK: - Init Tests

@Suite("RTMPPublisher — Init")
struct RTMPPublisherInitTests {

    @Test("Default init creates publisher in idle state")
    func defaultInit() async {
        let publisher = RTMPPublisher()
        let state = await publisher.state
        #expect(state == .idle)
    }

    @Test("Custom transport init uses provided transport")
    func customTransportInit() async {
        let mock = MockTransport()
        let publisher = RTMPPublisher(transport: mock)
        let state = await publisher.state
        #expect(state == .idle)
    }
}

// MARK: - Event Tests

@Suite("RTMPPublisher — Events")
struct RTMPPublisherEventTests {

    @Test("events stream is available")
    func eventsStreamAvailable() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        // The events property should be accessible without crash.
        _ = await publisher.events
    }

    @Test("events emitted during publish are buffered")
    func eventsEmittedDuringPublish() async throws {
        let (publisher, _) = await makeScriptedPublisher()
        let stream = await publisher.events

        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )

        // Events are buffered by AsyncStream. Read the first one.
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        #expect(first != nil)

        await publisher.disconnect()
    }
}

// MARK: - Configuration Integration Tests

@Suite("RTMPPublisher — Configuration")
struct RTMPPublisherConfigurationTests {

    @Test("publish with configuration transitions to publishing")
    func publishWithConfiguration() async throws {
        let (publisher, _) = await makeScriptedPublisher()
        let config = RTMPConfiguration(
            url: "rtmp://localhost/app", streamKey: "test"
        )
        try await publisher.publish(configuration: config)
        let state = await publisher.state
        #expect(state == .publishing)
        await publisher.disconnect()
    }

    @Test("publish with Twitch configuration uses correct params")
    func publishWithTwitchConfig() async throws {
        let (publisher, mock) = await makeScriptedPublisher()
        let config = RTMPConfiguration.twitch(
            streamKey: "test", useTLS: false
        )
        try await publisher.publish(configuration: config)
        let host = await mock.connectHost
        let port = await mock.connectPort
        #expect(host == "live.twitch.tv")
        #expect(port == 1935)
        await publisher.disconnect()
    }

    @Test("disconnect clears stored configuration")
    func disconnectClearsConfiguration() async throws {
        let (publisher, _) = await makeScriptedPublisher()
        let config = RTMPConfiguration(
            url: "rtmp://localhost/app", streamKey: "test"
        )
        try await publisher.publish(configuration: config)
        await publisher.disconnect()
        let stored = await publisher.currentConfiguration
        #expect(stored == nil)
    }
}
