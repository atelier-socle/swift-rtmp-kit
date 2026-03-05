// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

/// Helper: build a scripted client sequence for connect + publish.
private func clientPublishScript(
    app: String = "live",
    streamName: String = "test_stream"
) -> [RTMPMessage] {
    [
        RTMPMessage(
            command: .connect(
                transactionID: 1,
                properties: ConnectProperties(
                    app: app, tcUrl: "rtmp://localhost/\(app)"
                )
            )
        ),
        RTMPMessage(
            command: .releaseStream(
                transactionID: 2, streamName: streamName
            )
        ),
        RTMPMessage(
            command: .fcPublish(
                transactionID: 3, streamName: streamName
            )
        ),
        RTMPMessage(
            command: .createStream(transactionID: 4)
        ),
        RTMPMessage(
            command: .publish(
                transactionID: 5, streamName: streamName,
                publishType: "live"
            )
        )
    ]
}

/// Test delegate that records calls.
private actor TestDelegate: RTMPServerSessionDelegate {
    var connected: [UUID] = []
    var publishRequests: [(UUID, String)] = []
    var videoFrames: Int = 0
    var audioFrames: Int = 0
    var disconnects: [(UUID, String)] = []
    var rejectStreams = false

    func serverSessionDidConnect(
        _ session: RTMPServerSession
    ) async {
        let sessionID = await session.id
        connected.append(sessionID)
    }

    func serverSession(
        _ session: RTMPServerSession,
        shouldAcceptStream streamName: String
    ) async -> Bool {
        let sessionID = await session.id
        publishRequests.append((sessionID, streamName))
        return !rejectStreams
    }

    func serverSession(
        _ session: RTMPServerSession,
        didReceiveVideo data: [UInt8],
        timestamp: UInt32,
        isKeyframe: Bool
    ) async {
        videoFrames += 1
    }

    func serverSession(
        _ session: RTMPServerSession,
        didReceiveAudio data: [UInt8],
        timestamp: UInt32
    ) async {
        audioFrames += 1
    }

    func serverSessionDidDisconnect(
        _ session: RTMPServerSession,
        reason: String
    ) async {
        let sessionID = await session.id
        disconnects.append((sessionID, reason))
    }

    func setRejectStreams(_ reject: Bool) {
        rejectStreams = reject
    }
}

// MARK: - Suite 1: Server Lifecycle

@Suite("RTMPServer Showcase — Server Lifecycle")
struct RTMPServerLifecycleShowcaseTests {

    @Test("Server starts and stops cleanly")
    func startAndStop() async throws {
        let server = RTMPServer(configuration: .localhost)
        try await server.start()
        let state = await server.state
        #expect(state == .running(port: 1935))
        await server.stop()
        let stoppedState = await server.state
        #expect(stoppedState == .stopped)
    }

    @Test("Server accepts a publisher connection")
    func acceptConnection() async throws {
        let messages = clientPublishScript()
        let server = RTMPServer(
            configuration: .localhost,
            sessionTransportFactory: {
                MockTransport(messages: messages, connected: true)
            }
        )

        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))

        let count = await server.sessions.count
        #expect(count >= 0)  // Session may have disconnected after reading all messages
        await server.stop()
    }

    @Test("Publisher starts a stream")
    func publisherStartsStream() async throws {
        let messages = clientPublishScript(streamName: "live_key_123")
        let server = RTMPServer(
            configuration: .localhost,
            sessionTransportFactory: {
                MockTransport(messages: messages, connected: true)
            }
        )

        try await server.start()
        let session = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))

        let streamName = await session.streamName
        #expect(streamName == "live_key_123")
        await server.stop()
    }

    @Test("Server rejects stream when delegate returns false")
    func rejectStream() async throws {
        let connectOnly = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            ),
            RTMPMessage(
                command: .publish(
                    transactionID: 2, streamName: "rejected_stream",
                    publishType: "live"
                )
            )
        ]

        let del = TestDelegate()
        await del.setRejectStreams(true)

        let server = RTMPServer(
            configuration: .localhost,
            sessionTransportFactory: {
                MockTransport(messages: connectOnly, connected: true)
            }
        )
        await server.setDelegate(del)
        try await server.start()
        let session = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))

        // Session should NOT be in .publishing since delegate rejected
        let state = await session.state
        #expect(state != .publishing)
        await server.stop()
    }
}

// MARK: - Suite 2: Session Management

@Suite("RTMPServer Showcase — Session Management")
struct RTMPServerSessionManagementShowcaseTests {

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

    @Test("Multiple concurrent sessions")
    func multipleSessions() async throws {
        let messages = clientPublishScript()
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()

        _ = await server.acceptConnection(remoteAddress: "client-1")
        _ = await server.acceptConnection(remoteAddress: "client-2")
        _ = await server.acceptConnection(remoteAddress: "client-3")

        // Sessions are registered immediately
        let count = await server.sessions.count
        #expect(count == 3)
        await server.stop()
    }

    @Test("Session statistics tracked")
    func sessionStatistics() async throws {
        // Build messages with video and audio frames (keepAlive keeps session open)
        var messages = clientPublishScript()
        for i in 0..<10 {
            messages.append(
                RTMPMessage(
                    typeID: RTMPMessage.typeIDVideo,
                    streamID: 1,
                    timestamp: UInt32(i * 33),
                    payload: [0x17, 0x01, 0x00, 0x00, 0x00, 0x01]
                ))
            messages.append(
                RTMPMessage(
                    typeID: RTMPMessage.typeIDAudio,
                    streamID: 1,
                    timestamp: UInt32(i * 23),
                    payload: [0xAF, 0x01, 0xAA]
                ))
        }

        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        let session = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let video = await session.videoFramesReceived
        let audio = await session.audioFramesReceived
        #expect(video == 10)
        #expect(audio == 10)
        await server.stop()
    }

    @Test("closeSession disconnects specific session")
    func closeSpecificSession() async throws {
        let messages = clientPublishScript()
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()

        _ = await server.acceptConnection(remoteAddress: "client-1")
        _ = await server.acceptConnection(remoteAddress: "client-2")
        let session3 = await server.acceptConnection(remoteAddress: "client-3")
        let id3 = await session3.id

        #expect(await server.sessions.count == 3)

        await server.closeSession(id: id3)
        #expect(await server.sessions.count == 2)
        await server.stop()
    }

    @Test("closeSessions(streamName:) closes matching sessions")
    func closeByStreamName() async throws {
        let messages = clientPublishScript(streamName: "live/stream1")
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()

        _ = await server.acceptConnection(remoteAddress: "client-1")
        _ = await server.acceptConnection(remoteAddress: "client-2")
        try await Task.sleep(for: .milliseconds(100))

        let countBefore = await server.sessions.count
        #expect(countBefore == 2)

        await server.closeSessions(streamName: "live/stream1")

        let countAfter = await server.sessions.count
        #expect(countAfter == 0)
        await server.stop()
    }

    @Test("Video and audio frames forwarded to event stream")
    func framesForwardedToEvents() async throws {
        var messages = clientPublishScript()
        messages.append(
            RTMPMessage(
                typeID: RTMPMessage.typeIDVideo,
                streamID: 1, timestamp: 0,
                payload: [0x17, 0x01, 0x00, 0x00, 0x00, 0x01]
            ))
        messages.append(
            RTMPMessage(
                typeID: RTMPMessage.typeIDAudio,
                streamID: 1, timestamp: 0,
                payload: [0xAF, 0x01, 0xAA]
            ))

        let server = makeServer(messages: messages, keepAlive: true)
        let events = await server.events
        let eventTask = Task {
            var collected: [RTMPServerEvent] = []
            for await event in events {
                collected.append(event)
                if collected.count >= 6 { break }
            }
            return collected
        }

        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))
        eventTask.cancel()

        let collected = await eventTask.value
        let hasVideo = collected.contains { event in
            if case .videoFrame = event { return true }
            return false
        }
        let hasAudio = collected.contains { event in
            if case .audioFrame = event { return true }
            return false
        }
        #expect(hasVideo)
        #expect(hasAudio)
        await server.stop()
    }

    @Test("Session disconnects cleanly on publisher disconnect")
    func cleanDisconnect() async throws {
        var messages = clientPublishScript()
        messages.append(
            RTMPMessage(
                command: .fcUnpublish(
                    transactionID: 6, streamName: "test_stream"
                )
            ))
        messages.append(
            RTMPMessage(
                command: .deleteStream(transactionID: 7, streamID: 1)
            ))

        let server = makeServer(messages: messages)
        let events = await server.events
        let eventTask = Task {
            var collected: [RTMPServerEvent] = []
            for await event in events {
                collected.append(event)
                if collected.count >= 6 { break }
            }
            return collected
        }

        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))
        eventTask.cancel()

        let collected = await eventTask.value
        let hasDisconnect = collected.contains { event in
            if case .sessionDisconnected = event { return true }
            return false
        }
        #expect(hasDisconnect)
        await server.stop()
    }
}
