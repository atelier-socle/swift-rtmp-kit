// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

/// Helper: build a scripted client message sequence for connect + publish.
private func makeClientScript(
    app: String = "live",
    streamName: String = "test_key"
) -> [RTMPMessage] {
    [
        // connect
        RTMPMessage(
            command: .connect(
                transactionID: 1,
                properties: ConnectProperties(app: app, tcUrl: "rtmp://localhost/\(app)")
            )
        ),
        // releaseStream
        RTMPMessage(
            command: .releaseStream(transactionID: 2, streamName: streamName)
        ),
        // FCPublish
        RTMPMessage(
            command: .fcPublish(transactionID: 3, streamName: streamName)
        ),
        // createStream
        RTMPMessage(
            command: .createStream(transactionID: 4)
        ),
        // publish
        RTMPMessage(
            command: .publish(
                transactionID: 5, streamName: streamName, publishType: "live"
            )
        )
    ]
}

@Suite("RTMPServer — State")
struct RTMPServerStateTests {

    @Test("initial server state is .idle")
    func initialState() async {
        let server = RTMPServer(configuration: .localhost)
        let state = await server.state
        #expect(state == .idle)
    }

    @Test("sessions is empty initially")
    func emptySessions() async {
        let server = RTMPServer(configuration: .localhost)
        let sessions = await server.sessions
        #expect(sessions.isEmpty)
    }

    @Test("activeSessionCount is 0 initially")
    func zeroActiveSessions() async {
        let server = RTMPServer(configuration: .localhost)
        let count = await server.activeSessionCount
        #expect(count == 0)
    }

    @Test("start() transitions state to .running")
    func startTransition() async throws {
        let server = RTMPServer(configuration: .localhost)
        try await server.start()
        let state = await server.state
        #expect(state == .running(port: 1935))
        await server.stop()
    }

    @Test("stop() transitions state to .stopped")
    func stopTransition() async throws {
        let server = RTMPServer(configuration: .localhost)
        try await server.start()
        await server.stop()
        let state = await server.state
        #expect(state == .stopped)
    }
}

@Suite("RTMPServer — Session Handling")
struct RTMPServerSessionHandlingTests {

    private func makeServer(
        messages: [RTMPMessage],
        keepAlive: Bool = false
    ) -> RTMPServer {
        RTMPServer(
            configuration: .localhost,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: keepAlive,
                    connected: true
                )
            }
        )
    }

    @Test("simulated connect command → session state becomes .connected")
    func connectCommand() async throws {
        let messages = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            )
        ]
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        let session = await server.acceptConnection()

        // Wait for message processing
        try await Task.sleep(for: .milliseconds(50))

        let state = await session.state
        #expect(state == .connected)
        let appName = await session.appName
        #expect(appName == "live")

        await server.stop()
    }

    @Test("simulated publish command → session state becomes .publishing")
    func publishCommand() async throws {
        let messages = makeClientScript()
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        let session = await server.acceptConnection()

        try await Task.sleep(for: .milliseconds(50))

        let state = await session.state
        #expect(state == .publishing)
        let streamName = await session.streamName
        #expect(streamName == "test_key")

        await server.stop()
    }

    @Test("events stream emits .started after start()")
    func startedEvent() async throws {
        let server = RTMPServer(configuration: .localhost)
        let events = await server.events
        let eventTask = Task {
            var collected: [RTMPServerEvent] = []
            for await event in events {
                collected.append(event)
                if collected.count >= 1 { break }
            }
            return collected
        }

        try await server.start()
        try await Task.sleep(for: .milliseconds(50))
        eventTask.cancel()

        let collected = await eventTask.value
        guard let first = collected.first else {
            Issue.record("No events received")
            await server.stop()
            return
        }
        if case .started(let port) = first {
            #expect(port == 1935)
        } else {
            Issue.record("Expected .started event")
        }
        await server.stop()
    }

    @Test("events stream emits .sessionConnected when session connects")
    func sessionConnectedEvent() async throws {
        let messages = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            )
        ]
        let server = makeServer(messages: messages, keepAlive: true)
        let events = await server.events
        let eventTask = Task {
            var collected: [RTMPServerEvent] = []
            for await event in events {
                collected.append(event)
                if collected.count >= 2 { break }
            }
            return collected
        }

        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))
        eventTask.cancel()

        let collected = await eventTask.value
        let hasSessionConnected = collected.contains { event in
            if case .sessionConnected = event { return true }
            return false
        }
        #expect(hasSessionConnected)
        await server.stop()
    }

    @Test("events stream emits .streamStarted when publish command received")
    func streamStartedEvent() async throws {
        let messages = makeClientScript(streamName: "my_stream")
        let server = makeServer(messages: messages, keepAlive: true)
        let events = await server.events
        let eventTask = Task {
            var collected: [RTMPServerEvent] = []
            for await event in events {
                collected.append(event)
                if collected.count >= 4 { break }
            }
            return collected
        }

        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))
        eventTask.cancel()

        let collected = await eventTask.value
        let hasStreamStarted = collected.contains { event in
            if case .streamStarted(_, let name) = event {
                return name == "my_stream"
            }
            return false
        }
        #expect(hasStreamStarted)
        await server.stop()
    }

    @Test("closeSession(id:) removes session from sessions")
    func closeSessionByID() async throws {
        let messages = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            )
        ]
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        let session = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))

        let sessionID = await session.id
        var count = await server.sessions.count
        #expect(count >= 1)

        await server.closeSession(id: sessionID)
        count = await server.sessions.count
        #expect(count == 0)

        await server.stop()
    }

    @Test("stop() closes all active sessions")
    func stopClosesAllSessions() async throws {
        let messages = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            )
        ]
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))

        let countBefore = await server.sessions.count
        #expect(countBefore >= 1)

        await server.stop()
        let countAfter = await server.sessions.count
        #expect(countAfter == 0)
    }
}
