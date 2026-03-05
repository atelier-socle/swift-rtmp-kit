// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

@Suite("RTMPServer — Stream Management")
struct RTMPServerStreamManagementTests {

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

    private func makeServer(
        messages: [RTMPMessage],
        keepAlive: Bool = false,
        configuration: RTMPServerConfiguration = .localhost
    ) -> RTMPServer {
        RTMPServer(
            configuration: configuration,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: keepAlive,
                    connected: true
                )
            }
        )
    }

    @Test("activeStreamNames is empty initially")
    func emptyStreamNames() async {
        let server = RTMPServer(configuration: .localhost)
        let names = await server.activeStreamNames
        #expect(names.isEmpty)
    }

    @Test("activeStreamNames contains stream after publish")
    func streamNameAfterPublish() async throws {
        let messages = makeClientScript(streamName: "my_stream")
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let names = await server.activeStreamNames
        #expect(names.contains("my_stream"))
        await server.stop()
    }

    @Test("session(forStream:) returns the correct session")
    func sessionForStream() async throws {
        let messages = makeClientScript(streamName: "live/abc")
        let server = makeServer(messages: messages, keepAlive: true)
        try await server.start()
        let session = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let found = await server.session(forStream: "live/abc")
        let foundID = await found?.id
        let sessionID = await session.id
        #expect(foundID == sessionID)
        await server.stop()
    }

    @Test("session(forStream:) returns nil for unknown stream")
    func sessionForUnknownStream() async throws {
        let server = RTMPServer(configuration: .localhost)
        try await server.start()
        let found = await server.session(forStream: "nonexistent")
        #expect(found == nil)
        await server.stop()
    }

    @Test("attachRelay stores relay for stream")
    func attachRelay() async throws {
        let server = RTMPServer(configuration: .localhost)
        let relay = RTMPStreamRelay(
            destinations: [],
            transportFactory: { _ in
                MockTransport(messages: [], connected: true)
            }
        )
        try await server.start()
        await server.attachRelay(relay, toStream: "live/test")
        let hasRelay = await server.relays["live/test"] != nil
        #expect(hasRelay)
        await server.stop()
    }

    @Test("detachRelay removes relay")
    func detachRelay() async throws {
        let server = RTMPServer(configuration: .localhost)
        let relay = RTMPStreamRelay(
            destinations: [],
            transportFactory: { _ in
                MockTransport(messages: [], connected: true)
            }
        )
        try await server.start()
        await server.attachRelay(relay, toStream: "live/test")
        await server.detachRelay(fromStream: "live/test")
        let hasRelay = await server.relays["live/test"] != nil
        #expect(!hasRelay)
        await server.stop()
    }

    @Test("attachDVR stores DVR for stream")
    func attachDVR() async throws {
        let server = RTMPServer(configuration: .localhost)
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration()
        )
        try await server.start()
        await server.attachDVR(dvr, toStream: "live/record")
        let hasDVR = await server.dvrs["live/record"] != nil
        #expect(hasDVR)
        await server.stop()
    }

    @Test("detachDVR removes DVR")
    func detachDVR() async throws {
        let tempDir = "/tmp/rtmpkit_dvr_mgmt_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(
            atPath: tempDir, withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let server = RTMPServer(configuration: .localhost)
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                outputDirectory: tempDir
            )
        )
        try await server.start()
        try await dvr.start()
        await server.attachDVR(dvr, toStream: "live/record")
        let segment = try await server.detachDVR(
            fromStream: "live/record"
        )
        let hasDVR = await server.dvrs["live/record"] != nil
        #expect(!hasDVR)
        // segment may be nil if nothing was written
        _ = segment
        await server.stop()
    }
}
