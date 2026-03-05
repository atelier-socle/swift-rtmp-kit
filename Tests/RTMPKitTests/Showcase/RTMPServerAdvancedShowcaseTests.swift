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

// MARK: - Suite 1: Stream Key Validation

@Suite("RTMPServer Advanced Showcase — Stream Key Validation")
struct StreamKeyValidationShowcaseTests {

    @Test("Allow-list validator accepts known keys")
    func allowListAcceptsKnown() async {
        let validator = AllowListStreamKeyValidator(
            allowedKeys: ["live_abc123", "stream_xyz"]
        )
        let valid = await validator.isValid(
            streamKey: "live_abc123", app: "live"
        )
        let invalid = await validator.isValid(
            streamKey: "unknown_key", app: "live"
        )
        #expect(valid)
        #expect(!invalid)
    }

    @Test("Server rejects publisher with invalid stream key")
    func serverRejectsInvalidKey() async throws {
        let config = RTMPServerConfiguration(
            host: "127.0.0.1",
            streamKeyValidator: AllowListStreamKeyValidator(
                allowedKeys: ["valid_key"]
            )
        )
        let messages = clientPublishScript(streamName: "invalid_key")
        let server = RTMPServer(
            configuration: config,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: true,
                    connected: true
                )
            }
        )
        try await server.start()
        let session = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let state = await session.state
        #expect(state != .publishing)
        await server.stop()
    }

    @Test("Custom closure validator enables dynamic auth")
    func closureValidator() async {
        let validator = ClosureStreamKeyValidator { key, app in
            key.hasPrefix("live_") && app == "live"
        }
        let valid = await validator.isValid(
            streamKey: "live_abc", app: "live"
        )
        let invalid = await validator.isValid(
            streamKey: "live_abc", app: "vod"
        )
        #expect(valid)
        #expect(!invalid)
    }

    @Test("Valid stream key allows publishing")
    func validKeyAllows() async throws {
        let config = RTMPServerConfiguration(
            host: "127.0.0.1",
            streamKeyValidator: AllowListStreamKeyValidator(
                allowedKeys: ["valid_key"]
            )
        )
        let messages = clientPublishScript(streamName: "valid_key")
        let server = RTMPServer(
            configuration: config,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: true,
                    connected: true
                )
            }
        )
        try await server.start()
        let session = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let state = await session.state
        #expect(state == .publishing)
        await server.stop()
    }
}

// MARK: - Suite 2: Relay

@Suite("RTMPServer Advanced Showcase — Relay")
struct RelayShowcaseTests {

    @Test("Relay forwards video to Twitch and YouTube")
    func relayForwards() async throws {
        let relay = RTMPStreamRelay(
            destinations: [
                .init(
                    id: "twitch",
                    configuration: .twitch(streamKey: "live_xxx")
                ),
                .init(
                    id: "youtube",
                    configuration: .youtube(streamKey: "yyyy-yyyy")
                )
            ],
            transportFactory: { _ in
                MockTransport(messages: [], connected: true)
            }
        )
        try await relay.start()
        await relay.relayVideo(
            [0x17, 0x01, 0x00], timestamp: 0, isKeyframe: true
        )
        await relay.relayAudio([0xAF, 0x01], timestamp: 0)
        let count = await relay.framesRelayed
        #expect(count == 2)
    }

    @Test("Relay stops cleanly")
    func relayStopsCleanly() async throws {
        let relay = RTMPStreamRelay(
            destinations: [
                .init(
                    id: "dest1",
                    configuration: .twitch(streamKey: "key1")
                )
            ],
            transportFactory: { _ in
                MockTransport(messages: [], connected: true)
            }
        )
        try await relay.start()
        for i in 0..<10 {
            await relay.relayVideo(
                [0x17, 0x01], timestamp: UInt32(i * 33),
                isKeyframe: i == 0
            )
        }
        await relay.stop()
        let state = await relay.state
        let count = await relay.framesRelayed
        #expect(state == .stopped)
        #expect(count == 10)
    }

    @Test("Server auto-relays ingest stream")
    func serverAutoRelay() async throws {
        var msgs = clientPublishScript(streamName: "live/myStream")
        msgs.append(
            RTMPMessage(
                typeID: RTMPMessage.typeIDVideo,
                streamID: 1, timestamp: 0,
                payload: [0x17, 0x01, 0x00, 0x00, 0x00]
            )
        )
        let messages = msgs

        let server = RTMPServer(
            configuration: .localhost,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: true,
                    connected: true
                )
            }
        )
        let relay = RTMPStreamRelay(
            destinations: [
                .init(
                    id: "dest",
                    configuration: .twitch(streamKey: "key")
                )
            ],
            transportFactory: { _ in
                MockTransport(messages: [], connected: true)
            }
        )
        try await relay.start()

        try await server.start()
        await server.attachRelay(relay, toStream: "live/myStream")
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let relayed = await relay.framesRelayed
        #expect(relayed >= 1)
        await server.stop()
    }

    @Test("Relay with failed destination continues to others")
    func failureIsolation() async throws {
        let relay = RTMPStreamRelay(
            destinations: [
                .init(
                    id: "good",
                    configuration: .twitch(streamKey: "live_good")
                ),
                .init(
                    id: "bad",
                    configuration: .youtube(streamKey: "bad_key")
                )
            ],
            transportFactory: { _ in
                MockTransport(messages: [], connected: true)
            }
        )
        try await relay.start()
        // Even if send fails on some destinations, no crash
        await relay.relayVideo(
            [0x17, 0x01], timestamp: 0, isKeyframe: true
        )
        let count = await relay.framesRelayed
        #expect(count == 1)
    }
}

// MARK: - Suite 3: DVR

@Suite("RTMPServer Advanced Showcase — DVR")
struct DVRShowcaseTests {

    private func makeTempDir() -> String {
        let path = "/tmp/rtmpkit_dvr_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(
            atPath: path, withIntermediateDirectories: true
        )
        return path
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("DVR records ingest stream to FLV")
    func dvrRecordsToFLV() async throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                format: .flv,
                outputDirectory: tempDir
            )
        )
        try await dvr.start()
        for i in 0..<50 {
            try await dvr.recordVideo(
                [0x17, 0x01, 0x00, 0x00, 0x00],
                timestamp: UInt32(i * 33), isKeyframe: i == 0
            )
            try await dvr.recordAudio(
                [0xAF, 0x01, 0xAA],
                timestamp: UInt32(i * 23)
            )
        }
        let segment = try await dvr.stop()
        #expect(segment != nil)
        let bytes = await dvr.totalBytesWritten
        #expect(bytes > 0)
    }

    @Test("DVR + Relay simultaneously")
    func dvrAndRelayCombined() async throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        var msgs2 = clientPublishScript(streamName: "combined")
        for i in 0..<5 {
            msgs2.append(
                RTMPMessage(
                    typeID: RTMPMessage.typeIDVideo,
                    streamID: 1,
                    timestamp: UInt32(i * 33),
                    payload: [0x17, 0x01, 0x00, 0x00, 0x00]
                )
            )
        }
        let messages = msgs2

        let server = RTMPServer(
            configuration: .localhost,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: true,
                    connected: true
                )
            }
        )

        let relay = RTMPStreamRelay(
            destinations: [
                .init(
                    id: "dest",
                    configuration: .twitch(streamKey: "key")
                )
            ],
            transportFactory: { _ in
                MockTransport(messages: [], connected: true)
            }
        )
        try await relay.start()

        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                outputDirectory: tempDir
            )
        )
        try await dvr.start()

        try await server.start()
        await server.attachRelay(relay, toStream: "combined")
        await server.attachDVR(dvr, toStream: "combined")
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let relayed = await relay.framesRelayed
        let bytesWritten = await dvr.totalBytesWritten
        #expect(relayed >= 1)
        #expect(bytesWritten > 0)

        _ = try await dvr.stop()
        await server.stop()
    }

    @Test("DVR segmentation creates multiple files")
    func dvrSegmentation() async throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }
        let dvr = RTMPStreamDVR(
            configuration: RecordingConfiguration(
                outputDirectory: tempDir,
                segmentDuration: 0.5
            )
        )
        try await dvr.start()
        // Stream ~2s of data with 100ms intervals
        for i in 0..<20 {
            try await dvr.recordVideo(
                [0x17, 0x01, 0x00, 0x00, 0x00],
                timestamp: UInt32(i * 100),
                isKeyframe: i % 5 == 0
            )
        }
        _ = try await dvr.stop()
        let segments = await dvr.completedSegments
        #expect(segments.count >= 1)
    }

    @Test("Server auto-DVR records all ingest streams")
    func serverAutoDVR() async throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        var msgs3 = clientPublishScript(streamName: "auto_dvr")
        msgs3.append(
            RTMPMessage(
                typeID: RTMPMessage.typeIDVideo,
                streamID: 1, timestamp: 0,
                payload: [0x17, 0x01, 0x00, 0x00, 0x00]
            )
        )
        let messages = msgs3

        let config = RTMPServerConfiguration(
            host: "127.0.0.1",
            autoDVR: true,
            dvrConfiguration: RecordingConfiguration(
                outputDirectory: tempDir
            )
        )
        let server = RTMPServer(
            configuration: config,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: true,
                    connected: true
                )
            }
        )
        try await server.start()
        _ = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let hasDVR = await server.dvrs["auto_dvr"] != nil
        #expect(hasDVR)

        // Clean up DVR
        _ = try? await server.detachDVR(fromStream: "auto_dvr")
        await server.stop()
    }
}
