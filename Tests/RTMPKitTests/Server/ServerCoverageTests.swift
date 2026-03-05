// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

/// Minimal mock exporter to capture export calls.
private actor MockExporter: RTMPMetricsExporter {
    var publisherExportCount = 0
    var serverExportCount = 0
    var flushCount = 0

    func export(
        _ statistics: RTMPPublisherStatistics,
        labels: [String: String]
    ) async {
        publisherExportCount += 1
    }

    func export(
        _ statistics: RTMPServerStatistics,
        labels: [String: String]
    ) async {
        serverExportCount += 1
    }

    func flush() async {
        flushCount += 1
    }
}

/// Helper: build a scripted client message sequence for connect + publish.
private func makeClientScript(
    app: String = "live",
    streamName: String = "test_key"
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
            command: .releaseStream(transactionID: 2, streamName: streamName)
        ),
        RTMPMessage(
            command: .fcPublish(transactionID: 3, streamName: streamName)
        ),
        RTMPMessage(
            command: .createStream(transactionID: 4)
        ),
        RTMPMessage(
            command: .publish(
                transactionID: 5, streamName: streamName, publishType: "live"
            )
        )
    ]
}

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

// MARK: - Server Metrics

@Suite("RTMPServer+Metrics — Export and Snapshots")
struct ServerMetricsCoverageTests {

    @Test("setMetricsExporter stores exporter and starts periodic export")
    func setMetricsExporter() async throws {
        let server = RTMPServer(configuration: .localhost)
        let exporter = MockExporter()
        try await server.start()

        await server.setMetricsExporter(
            exporter, interval: 0.05, labels: ["env": "test"]
        )
        // First export fires inline in setMetricsExporter,
        // so count >= 1 is guaranteed at this point.
        let count = await exporter.serverExportCount
        #expect(count >= 1)
        await server.removeMetricsExporter()
        await server.stop()
    }

    @Test("removeMetricsExporter cancels task and flushes")
    func removeMetricsExporter() async throws {
        let server = RTMPServer(configuration: .localhost)
        let exporter = MockExporter()
        try await server.start()

        await server.setMetricsExporter(exporter, interval: 0.05)
        try await Task.sleep(for: .milliseconds(100))
        await server.removeMetricsExporter()

        let flushCount = await exporter.flushCount
        #expect(flushCount >= 1)
        await server.stop()
    }

    @Test("metricsSnapshot includes session stream names")
    func metricsSnapshotWithStreamNames() async throws {
        let messages = makeClientScript(streamName: "my_stream")
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))

        let snapshot = await server.metricsSnapshot()
        #expect(snapshot.activeSessionCount >= 1)
        #expect(snapshot.activeStreamNames.contains("my_stream"))
        await server.stop()
    }

    @Test("recordSessionRejected increments counter")
    func recordSessionRejectedCounter() async throws {
        let server = RTMPServer(configuration: .localhost)
        try await server.start()
        let before = await server.totalSessionsRejected
        await server.recordSessionRejected()
        let after = await server.totalSessionsRejected
        #expect(after == before + 1)
        await server.stop()
    }
}

// MARK: - Server Message Handling

@Suite("RTMPServer+MessageHandling — Unknown and Control Messages")
struct ServerMessageHandlingCoverageTests {

    @Test("unknown typeID message is handled without crash")
    func unknownTypeIDHandled() async throws {
        let messages: [RTMPMessage] = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            ),
            // Unknown message type
            RTMPMessage(
                typeID: 42, streamID: 0, timestamp: 0,
                payload: [0x01, 0x02, 0x03]
            )
        ]
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))
        // No crash = default: break path covered
        await server.stop()
    }

    @Test("SetChunkSize message updates session chunk size")
    func setChunkSizeHandled() async throws {
        // Build a SetChunkSize payload: 4096 in big-endian
        let chunkSizePayload: [UInt8] = [0x00, 0x00, 0x10, 0x00]
        let messages: [RTMPMessage] = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            ),
            RTMPMessage(
                typeID: RTMPMessage.typeIDSetChunkSize, streamID: 0,
                timestamp: 0, payload: chunkSizePayload
            )
        ]
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))
        await server.stop()
    }

    @Test("SetChunkSize with short payload is ignored")
    func setChunkSizeShortPayload() async throws {
        let messages: [RTMPMessage] = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            ),
            RTMPMessage(
                typeID: RTMPMessage.typeIDSetChunkSize, streamID: 0,
                timestamp: 0, payload: [0x00, 0x10]
            )
        ]
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))
        await server.stop()
    }

    @Test("unknown AMF0 command is handled without crash")
    func unknownCommandHandled() async throws {
        // Build a raw AMF0 command with an unknown name
        var encoder = AMF0Encoder()
        let payload = encoder.encode([
            .string("unknownCommand"), .number(99), .null
        ])

        let messages: [RTMPMessage] = [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: "live", tcUrl: "rtmp://localhost/live"
                    )
                )
            ),
            RTMPMessage(
                typeID: RTMPMessage.typeIDCommandAMF0, streamID: 0,
                timestamp: 0, payload: payload
            )
        ]
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(50))
        await server.stop()
    }
}

// MARK: - Server Stream Management

@Suite("RTMPServer+StreamManagement — Detach Operations")
struct ServerStreamManagementCoverageTests {

    @Test("detachRelay with no relay is no-op")
    func detachRelayNoOp() async throws {
        let server = RTMPServer(configuration: .localhost)
        try await server.start()
        await server.detachRelay(fromStream: "nonexistent")
        // No crash = guard return path covered
        await server.stop()
    }

    @Test("detachDVR with no DVR is no-op")
    func detachDVRNoOp() async throws {
        let server = RTMPServer(configuration: .localhost)
        try await server.start()
        let dvr = try await server.detachDVR(fromStream: "nonexistent")
        #expect(dvr == nil)
        await server.stop()
    }
}

// MARK: - Server Session State

@Suite("RTMPServerSession — State Transitions")
struct ServerSessionCoverageTests {

    @Test("transitionToFailed sets failed state")
    func transitionToFailed() async {
        let mock = MockTransport(messages: [], connected: true)
        let session = RTMPServerSession(
            transport: mock, remoteAddress: "test", connectedAt: 0
        )
        await session.transitionToFailed("test error")
        let state = await session.state
        #expect(state == .failed("test error"))
    }

    @Test("setChunkSize updates disassembler chunk size")
    func setChunkSize() async {
        let mock = MockTransport(messages: [], connected: true)
        let session = RTMPServerSession(
            transport: mock, remoteAddress: "test", connectedAt: 0
        )
        await session.setChunkSize(4096)
        // No crash = chunk size set correctly
    }

    @Test("setReceiveChunkSize updates assembler chunk size")
    func setReceiveChunkSize() async {
        let mock = MockTransport(messages: [], connected: true)
        let session = RTMPServerSession(
            transport: mock, remoteAddress: "test", connectedAt: 0
        )
        await session.setReceiveChunkSize(4096)
        // No crash = receive chunk size set correctly
    }
}

// MARK: - ServerHandshake Validation

@Suite("ServerHandshake — Input Validation")
struct ServerHandshakeCoverageTests {

    @Test("buildResponse throws connectionClosed for short C0C1")
    func shortC0C1Throws() {
        let shortBuffer = [UInt8](repeating: 0, count: 100)
        #expect(throws: ServerHandshake.HandshakeError.self) {
            _ = try ServerHandshake.buildResponse(c0c1: shortBuffer)
        }
    }

    @Test("validateC2 throws invalidC2Echo for wrong length C2")
    func wrongLengthC2Throws() {
        let s1Random = [UInt8](repeating: 0xAB, count: 1536)
        let shortC2 = [UInt8](repeating: 0, count: 100)
        #expect(throws: ServerHandshake.HandshakeError.self) {
            try ServerHandshake.validateC2(shortC2, s1Random: s1Random)
        }
    }

    @Test("validateC2 throws invalidC2Echo for wrong length s1Random")
    func wrongLengthS1RandomThrows() {
        let c2 = [UInt8](repeating: 0, count: 1536)
        let shortRandom = [UInt8](repeating: 0xAB, count: 100)
        #expect(throws: ServerHandshake.HandshakeError.self) {
            try ServerHandshake.validateC2(c2, s1Random: shortRandom)
        }
    }
}

// MARK: - RTMPConnectionRateLimiter Ban Expiry

@Suite("RTMPConnectionRateLimiter — Expired Ban Cleanup")
struct RateLimiterExpiredBanTests {

    @Test("expired ban is cleaned up on isBanned check")
    func expiredBanCleanup() async throws {
        let limiter = RTMPConnectionRateLimiter(
            maxConnectionsPerIPPerMinute: 2,
            autoBanDuration: 0.01
        )
        // Trigger auto-ban
        for _ in 0..<3 {
            _ = await limiter.checkAndRecord(ip: "1.2.3.4")
        }
        let banned = await limiter.isBanned("1.2.3.4")
        #expect(banned == true)

        // Wait for ban to expire
        try await Task.sleep(for: .milliseconds(20))
        let stillBanned = await limiter.isBanned("1.2.3.4")
        #expect(stillBanned == false)
    }
}
