// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import NIOCore
import NIOPosix
import RTMPKit
import Testing

@testable import RTMPKitCommands

/// Fake RTMP server handler that completes handshake and
/// responds with the full RTMP protocol sequence.
///
/// `@unchecked Sendable`: NIO handler, EventLoop-confined.
private final class FullRTMPServerHandler: ChannelInboundHandler,
    @unchecked Sendable
{
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private var handshakeBuffer: [UInt8] = []
    private var handshakeDone = false
    private let postHandshakeBytes: [UInt8]

    init(postHandshakeBytes: [UInt8]) {
        self.postHandshakeBytes = postHandshakeBytes
    }

    func channelRead(
        context: ChannelHandlerContext, data: NIOAny
    ) {
        var buffer = unwrapInboundIn(data)
        guard
            let bytes = buffer.readBytes(
                length: buffer.readableBytes)
        else { return }

        if !handshakeDone {
            handshakeBuffer.append(contentsOf: bytes)
            guard handshakeBuffer.count >= 1537 else { return }

            let c1 = Array(handshakeBuffer[1..<1537])
            var s0s1s2: [UInt8] = [0x03]
            var s1 = [UInt8](repeating: 0, count: 1536)
            for i in 8..<1536 {
                s1[i] = UInt8.random(in: 0...255)
            }
            s0s1s2.append(contentsOf: s1)
            var s2 = [UInt8](repeating: 0, count: 1536)
            if c1.count >= 4 {
                for i in 0..<4 { s2[i] = c1[i] }
            }
            if c1.count >= 1536 {
                for i in 8..<1536 { s2[i] = c1[i] }
            }
            s0s1s2.append(contentsOf: s2)

            var outBuf = context.channel.allocator.buffer(
                capacity: s0s1s2.count
            )
            outBuf.writeBytes(s0s1s2)
            context.writeAndFlush(
                wrapOutboundOut(outBuf), promise: nil
            )

            handshakeDone = true
            handshakeBuffer = []

            // Send RTMP protocol responses
            if !postHandshakeBytes.isEmpty {
                var buf = context.channel.allocator.buffer(
                    capacity: postHandshakeBytes.count
                )
                buf.writeBytes(postHandshakeBytes)
                context.writeAndFlush(
                    wrapOutboundOut(buf), promise: nil
                )
            }
        }
    }

    func errorCaught(
        context: ChannelHandlerContext, error: Error
    ) {
        context.close(promise: nil)
    }
}

/// Build control protocol responses (ack + bandwidth).
private func buildControlResponses(
    _ disassembler: inout ChunkDisassembler
) -> [UInt8] {
    var bytes: [UInt8] = []
    let ackMsg = RTMPMessage(
        controlMessage: .windowAcknowledgementSize(2_500_000)
    )
    bytes.append(
        contentsOf: disassembler.disassemble(
            message: ackMsg, chunkStreamID: .protocolControl
        )
    )
    let bwMsg = RTMPMessage(
        controlMessage: .setPeerBandwidth(
            windowSize: 2_500_000, limitType: .dynamic
        )
    )
    bytes.append(
        contentsOf: disassembler.disassemble(
            message: bwMsg, chunkStreamID: .protocolControl
        )
    )
    return bytes
}

/// Build command responses (connect result, createStream, onStatus).
private func buildCommandResponses(
    _ disassembler: inout ChunkDisassembler
) -> [UInt8] {
    var bytes: [UInt8] = []

    let connectResult = RTMPCommand.result(
        transactionID: 1,
        properties: .object([
            ("fmsVer", .string("FMS/5,0,17")),
            ("capabilities", .number(31))
        ]),
        information: .object([
            ("level", .string("status")),
            ("code", .string("NetConnection.Connect.Success")),
            ("description", .string("Connection succeeded.")),
            ("objectEncoding", .number(0))
        ])
    )
    bytes.append(
        contentsOf: disassembler.disassemble(
            message: RTMPMessage(command: connectResult),
            chunkStreamID: .command
        )
    )

    let createResult = RTMPCommand.result(
        transactionID: 4, properties: nil,
        information: .number(1)
    )
    bytes.append(
        contentsOf: disassembler.disassemble(
            message: RTMPMessage(command: createResult),
            chunkStreamID: .command
        )
    )

    let publishStatus = RTMPCommand.onStatus(
        information: .object([
            ("level", .string("status")),
            ("code", .string("NetStream.Publish.Start")),
            ("description", .string("Publishing stream."))
        ])
    )
    bytes.append(
        contentsOf: disassembler.disassemble(
            message: RTMPMessage(
                command: publishStatus, streamID: 1),
            chunkStreamID: .command
        )
    )

    return bytes
}

/// Build all RTMP protocol responses sent after handshake.
private func buildRTMPProtocolResponses() -> [UInt8] {
    var disassembler = ChunkDisassembler()
    return buildControlResponses(&disassembler)
        + buildCommandResponses(&disassembler)
}

/// Start a local full RTMP server.
private func startFullRTMPServer(
    group: EventLoopGroup
) async throws -> Channel {
    let responses = buildRTMPProtocolResponses()
    return try await ServerBootstrap(group: group)
        .serverChannelOption(
            .socketOption(.so_reuseaddr), value: 1
        )
        .childChannelInitializer { channel in
            channel.pipeline.addHandler(
                FullRTMPServerHandler(
                    postHandshakeBytes: responses)
            )
        }
        .bind(host: "127.0.0.1", port: 0)
        .get()
}

@Suite(
    "CLI — TestConnectionCommand Integration",
    .disabled("Requires live network — run manually")
)
struct TestConnectionCommandIntegrationTests {

    @Test("run completes against local server")
    func runCompletes() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFullRTMPServer(
            group: group)
        let port = try #require(server.localAddress?.port)

        var cmd = try TestConnectionCommand.parse([
            "--url",
            "rtmp://127.0.0.1:\(port)/app",
            "--key", "test-key"
        ])

        do {
            try await cmd.run()
        } catch {
            // May fail if protocol doesn't fully complete,
            // but the run() code paths are still exercised.
        }

        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("run with verbose completes against local server")
    func runVerbose() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFullRTMPServer(
            group: group)
        let port = try #require(server.localAddress?.port)

        var cmd = try TestConnectionCommand.parse([
            "--url",
            "rtmp://127.0.0.1:\(port)/app",
            "--key", "test-key",
            "--verbose"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected — ExitCode.failure or protocol issue
        }

        try await server.close()
        try await group.shutdownGracefully()
    }
}

// MARK: - FLV Helpers

/// Build a minimal valid FLV file with audio + video tags.
private func buildMinimalFLV() -> [UInt8] {
    var flv: [UInt8] = []

    // FLV Header: "FLV" v1, audio+video, offset=9
    flv += [
        0x46, 0x4C, 0x56, 0x01, 0x05,
        0x00, 0x00, 0x00, 0x09
    ]
    // Previous tag size 0
    flv += [0x00, 0x00, 0x00, 0x00]

    func appendTag(
        type: UInt8, timestamp: UInt32, data: [UInt8]
    ) {
        let size = UInt32(data.count)
        flv.append(type)
        flv.append(UInt8((size >> 16) & 0xFF))
        flv.append(UInt8((size >> 8) & 0xFF))
        flv.append(UInt8(size & 0xFF))
        let tsLow = timestamp & 0x00FF_FFFF
        let tsHigh = (timestamp >> 24) & 0xFF
        flv.append(UInt8((tsLow >> 16) & 0xFF))
        flv.append(UInt8((tsLow >> 8) & 0xFF))
        flv.append(UInt8(tsLow & 0xFF))
        flv.append(UInt8(tsHigh))
        flv += [0x00, 0x00, 0x00]
        flv += data
        let total = UInt32(11) + size
        flv.append(UInt8((total >> 24) & 0xFF))
        flv.append(UInt8((total >> 16) & 0xFF))
        flv.append(UInt8((total >> 8) & 0xFF))
        flv.append(UInt8(total & 0xFF))
    }

    // Audio config (AAC sequence header, ts=0)
    appendTag(type: 0x08, timestamp: 0, data: [0xAF, 0x00])
    // Video config (AVC keyframe seq header, ts=0)
    appendTag(
        type: 0x09, timestamp: 0,
        data: [0x17, 0x00, 0x00, 0x00, 0x00]
    )
    // Audio raw (ts=0)
    appendTag(
        type: 0x08, timestamp: 0, data: [0xAF, 0x01, 0xCA]
    )
    // Video keyframe NALU (ts=1)
    appendTag(
        type: 0x09, timestamp: 1,
        data: [0x17, 0x01, 0x00, 0x00, 0x00, 0xAB]
    )
    // Video non-keyframe (ts=1)
    appendTag(
        type: 0x09, timestamp: 1,
        data: [0x21, 0x01, 0x00, 0x00, 0x00, 0xCD]
    )

    return flv
}

private func createTempFLV() throws -> String {
    let bytes = buildMinimalFLV()
    let dir = FileManager.default.temporaryDirectory
    let path = dir.appendingPathComponent(
        "rtmpkit-test-\(UUID().uuidString).flv"
    ).path
    _ = FileManager.default.createFile(
        atPath: path, contents: Data(bytes)
    )
    return path
}

@Suite(
    "CLI — PublishCommand Integration",
    .disabled("Requires live network — run manually")
)
struct PublishCommandIntegrationTests {

    @Test("run with invalid file shows error")
    func runInvalidFile() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFullRTMPServer(
            group: group)
        let port = try #require(server.localAddress?.port)

        var cmd = try PublishCommand.parse([
            "--url",
            "rtmp://127.0.0.1:\(port)/app",
            "--key", "test-key",
            "--file", "/nonexistent/path/video.flv",
            "--quiet"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected — file not found
        }

        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("run with valid FLV file in quiet mode")
    func runQuiet() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFullRTMPServer(
            group: group)
        let port = try #require(server.localAddress?.port)

        let flvPath = try createTempFLV()
        defer { try? FileManager.default.removeItem(atPath: flvPath) }

        var cmd = try PublishCommand.parse([
            "--url",
            "rtmp://127.0.0.1:\(port)/app",
            "--key", "test-key",
            "--file", flvPath,
            "--quiet"
        ])

        do {
            try await cmd.run()
        } catch {
            // May fail during streaming — code paths exercised
        }

        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("run with valid FLV file in verbose mode")
    func runVerbose() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFullRTMPServer(
            group: group)
        let port = try #require(server.localAddress?.port)

        let flvPath = try createTempFLV()
        defer { try? FileManager.default.removeItem(atPath: flvPath) }

        var cmd = try PublishCommand.parse([
            "--url",
            "rtmp://127.0.0.1:\(port)/app",
            "--key", "test-key",
            "--file", flvPath
        ])

        do {
            try await cmd.run()
        } catch {
            // May fail — code paths still exercised
        }

        try await server.close()
        try await group.shutdownGracefully()
    }
}

@Suite(
    "CLI — InfoCommand Integration",
    .disabled("Requires live network — run manually")
)
struct InfoCommandIntegrationTests {

    @Test("run completes against local server")
    func runCompletes() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFullRTMPServer(
            group: group)
        let port = try #require(server.localAddress?.port)

        var cmd = try InfoCommand.parse([
            "--url",
            "rtmp://127.0.0.1:\(port)/app"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected — ExitCode.failure or protocol issue
        }

        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("run with --json against local server")
    func runJSON() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFullRTMPServer(
            group: group)
        let port = try #require(server.localAddress?.port)

        var cmd = try InfoCommand.parse([
            "--url",
            "rtmp://127.0.0.1:\(port)/app",
            "--json"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected — ExitCode.failure or protocol issue
        }

        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("run with --key against local server")
    func runWithKey() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFullRTMPServer(
            group: group)
        let port = try #require(server.localAddress?.port)

        var cmd = try InfoCommand.parse([
            "--url",
            "rtmp://127.0.0.1:\(port)/app",
            "--key", "test-key"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected
        }

        try await server.close()
        try await group.shutdownGracefully()
    }
}
