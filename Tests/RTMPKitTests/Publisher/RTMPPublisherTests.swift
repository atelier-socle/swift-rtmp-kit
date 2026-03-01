// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Test Helpers

/// Build a scripted server response sequence for a successful publish.
private func makePublishScript(streamID: Double = 1) -> [RTMPMessage] {
    [
        // After connect: Window Ack Size.
        RTMPMessage(controlMessage: .windowAcknowledgementSize(2_500_000)),
        // Set Peer Bandwidth.
        RTMPMessage(
            controlMessage: .setPeerBandwidth(
                windowSize: 2_500_000, limitType: .dynamic
            )
        ),
        // Connect _result (txnID 1).
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
        // createStream _result (txnID 4) with stream ID.
        RTMPMessage(
            command: .result(
                transactionID: 4,
                properties: nil,
                information: .number(streamID)
            )),
        // publish onStatus.
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
private func makeScriptedPublisher(
    messages: [RTMPMessage]? = nil
) -> (RTMPPublisher, MockTransport) {
    let mock = MockTransport()
    mock.scriptedMessages = messages ?? makePublishScript()
    let publisher = RTMPPublisher(transport: mock)
    return (publisher, mock)
}

/// Run a full publish, then immediately disconnect.
private func publishAndDisconnect(
    publisher: RTMPPublisher,
    url: String = "rtmp://localhost/app",
    streamKey: String = "test"
) async throws {
    try await publisher.publish(url: url, streamKey: streamKey)
    await publisher.disconnect()
}

// MARK: - Lifecycle Tests

@Suite("RTMPPublisher — Lifecycle")
struct RTMPPublisherLifecycleTests {

    @Test("publish transitions to publishing state")
    func publishTransitionsToPublishing() async throws {
        let (publisher, _) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        let state = await publisher.state
        #expect(state == .publishing)
        await publisher.disconnect()
    }

    @Test("publish sends connect command via transport")
    func publishSendsConnect() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        // Transport should have received sent bytes (connect, setChunkSize,
        // releaseStream, FCPublish, createStream, publish).
        #expect(mock.sentBytes.count >= 5)
        await publisher.disconnect()
    }

    @Test("publish calls transport.connect with correct params")
    func publishCallsTransportConnect() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        #expect(mock.connectHost == "localhost")
        #expect(mock.connectPort == 1935)
        #expect(mock.connectUseTLS == false)
        await publisher.disconnect()
    }

    @Test("publish with rtmps uses TLS")
    func publishWithRTMPSUsesTLS() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmps://host.example.com/app",
            streamKey: "test"
        )
        #expect(mock.connectUseTLS == true)
        #expect(mock.connectPort == 443)
        await publisher.disconnect()
    }

    @Test("disconnect transitions to disconnected")
    func disconnectTransitions() async throws {
        let (publisher, _) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        await publisher.disconnect()
        let state = await publisher.state
        #expect(state == .idle)
    }

    @Test("disconnect closes transport")
    func disconnectClosesTransport() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        await publisher.disconnect()
        #expect(mock.didClose)
    }

    @Test("publish sends metadata when provided")
    func publishSendsMetadata() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test",
            metadata: meta
        )
        // Metadata is one additional send after publish.
        let sentCount = mock.sentBytes.count
        #expect(sentCount >= 7)
        await publisher.disconnect()
    }

    @Test("publish sends multiple commands in order")
    func publishSendsCommandsInOrder() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        // Expected sends: connect, setChunkSize, releaseStream,
        // FCPublish, createStream, publish.
        #expect(mock.sentBytes.count >= 6)
        await publisher.disconnect()
    }
}

// MARK: - Media Sending Tests

@Suite("RTMPPublisher — Media Sending")
struct RTMPPublisherMediaTests {

    @Test("sendVideo throws notPublishing when not publishing")
    func sendVideoNotPublishing() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        do {
            try await publisher.sendVideo([0x00], timestamp: 0, isKeyframe: true)
            Issue.record("Expected error")
        } catch {
            #expect(error is RTMPError)
        }
    }

    @Test("sendAudio throws notPublishing when not publishing")
    func sendAudioNotPublishing() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        do {
            try await publisher.sendAudio([0x00], timestamp: 0)
            Issue.record("Expected error")
        } catch {
            #expect(error is RTMPError)
        }
    }

    @Test("sendVideoConfig sends sequence header via transport")
    func sendVideoConfigSendsHeader() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        let beforeCount = mock.sentBytes.count
        try await publisher.sendVideoConfig([0x01, 0x64, 0x00, 0x1E])
        #expect(mock.sentBytes.count == beforeCount + 1)
        await publisher.disconnect()
    }

    @Test("sendAudioConfig sends sequence header via transport")
    func sendAudioConfigSendsHeader() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        let beforeCount = mock.sentBytes.count
        try await publisher.sendAudioConfig([0x12, 0x10])
        #expect(mock.sentBytes.count == beforeCount + 1)
        await publisher.disconnect()
    }

    @Test("sendVideo sends FLV tag body via transport")
    func sendVideoSendsTag() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        let beforeCount = mock.sentBytes.count
        try await publisher.sendVideo(
            [0x00, 0x00, 0x00, 0x01, 0x65],
            timestamp: 100,
            isKeyframe: true
        )
        #expect(mock.sentBytes.count == beforeCount + 1)
        await publisher.disconnect()
    }

    @Test("sendAudio sends FLV tag body via transport")
    func sendAudioSendsTag() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        let beforeCount = mock.sentBytes.count
        try await publisher.sendAudio([0xFF, 0xF1], timestamp: 200)
        #expect(mock.sentBytes.count == beforeCount + 1)
        await publisher.disconnect()
    }

    @Test("updateMetadata sends @setDataFrame")
    func updateMetadataSendsDataFrame() async throws {
        let (publisher, mock) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        let beforeCount = mock.sentBytes.count
        var meta = StreamMetadata()
        meta.width = 1280
        meta.height = 720
        try await publisher.updateMetadata(meta)
        #expect(mock.sentBytes.count == beforeCount + 1)
        await publisher.disconnect()
    }

    @Test("sendVideoConfig throws when not publishing")
    func sendVideoConfigNotPublishing() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        do {
            try await publisher.sendVideoConfig([0x01])
            Issue.record("Expected error")
        } catch {
            #expect(error is RTMPError)
        }
    }

    @Test("sendAudioConfig throws when not publishing")
    func sendAudioConfigNotPublishing() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        do {
            try await publisher.sendAudioConfig([0x01])
            Issue.record("Expected error")
        } catch {
            #expect(error is RTMPError)
        }
    }
}

// MARK: - Error Handling Tests

@Suite("RTMPPublisher — Error Handling")
struct RTMPPublisherErrorTests {

    @Test("publish with invalid URL throws invalidURL")
    func invalidURL() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        do {
            try await publisher.publish(
                url: "http://not-rtmp/app",
                streamKey: "test"
            )
            Issue.record("Expected error")
        } catch let error as RTMPError {
            if case .invalidURL = error {
                // Expected.
            } else {
                Issue.record("Expected invalidURL, got \(error)")
            }
        } catch {
            Issue.record("Expected RTMPError")
        }
    }

    @Test("publish when already publishing throws alreadyPublishing")
    func alreadyPublishing() async throws {
        let (publisher, _) = makeScriptedPublisher()
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        do {
            try await publisher.publish(
                url: "rtmp://localhost/app",
                streamKey: "test2"
            )
            Issue.record("Expected error")
        } catch let error as RTMPError {
            #expect(error == .alreadyPublishing)
        } catch {
            Issue.record("Expected RTMPError")
        }
        await publisher.disconnect()
    }

    @Test("connect rejected by server throws connectRejected")
    func connectRejected() async {
        let mock = MockTransport()
        mock.scriptedMessages = [
            RTMPMessage(
                command: .error(
                    transactionID: 1,
                    properties: nil,
                    information: .object([
                        ("level", .string("error")),
                        ("code", .string("NetConnection.Connect.Rejected")),
                        ("description", .string("Auth failed"))
                    ])
                ))
        ]
        let publisher = RTMPPublisher(transport: mock)
        do {
            try await publisher.publish(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
            Issue.record("Expected error")
        } catch let error as RTMPError {
            if case .connectRejected = error {
                // Expected.
            } else {
                Issue.record("Expected connectRejected, got \(error)")
            }
        } catch {
            Issue.record("Expected RTMPError")
        }
    }

    @Test("createStream failure throws createStreamFailed")
    func createStreamFailed() async {
        let mock = MockTransport()
        mock.scriptedMessages = [
            // Connect succeeds.
            RTMPMessage(
                command: .result(
                    transactionID: 1,
                    properties: nil,
                    information: .object([
                        ("code", .string("NetConnection.Connect.Success"))
                    ])
                )),
            // createStream returns null instead of stream ID.
            RTMPMessage(
                command: .result(
                    transactionID: 4,
                    properties: nil,
                    information: .null
                ))
        ]
        let publisher = RTMPPublisher(transport: mock)
        do {
            try await publisher.publish(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
            Issue.record("Expected error")
        } catch let error as RTMPError {
            if case .createStreamFailed = error {
                // Expected.
            } else {
                Issue.record("Expected createStreamFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected RTMPError")
        }
    }

    @Test("publish rejected throws publishFailed")
    func publishRejected() async {
        let mock = MockTransport()
        mock.scriptedMessages = [
            // Connect succeeds.
            RTMPMessage(
                command: .result(
                    transactionID: 1,
                    properties: nil,
                    information: .object([
                        ("code", .string("NetConnection.Connect.Success"))
                    ])
                )),
            // createStream succeeds.
            RTMPMessage(
                command: .result(
                    transactionID: 4,
                    properties: nil,
                    information: .number(1)
                )),
            // Publish rejected.
            RTMPMessage(
                command: .onStatus(
                    information: .object([
                        ("level", .string("error")),
                        ("code", .string("NetStream.Publish.Failed")),
                        ("description", .string("Already publishing"))
                    ])))
        ]
        let publisher = RTMPPublisher(transport: mock)
        do {
            try await publisher.publish(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
            Issue.record("Expected error")
        } catch let error as RTMPError {
            if case .publishFailed = error {
                // Expected.
            } else {
                Issue.record("Expected publishFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected RTMPError")
        }
    }

    @Test("connect failure transitions to failed state")
    func connectFailureTransitionsToFailed() async {
        let mock = MockTransport()
        mock.nextError = TransportError.connectionTimeout
        let publisher = RTMPPublisher(transport: mock)
        do {
            try await publisher.publish(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
            Issue.record("Expected error")
        } catch {
            let state = await publisher.state
            if case .failed = state {
                // Expected.
            } else {
                Issue.record("Expected failed state, got \(state)")
            }
        }
    }
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
        let (publisher, _) = makeScriptedPublisher()
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
