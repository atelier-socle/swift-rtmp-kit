// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import NIOCore
import NIOPosix
import Testing

@testable import RTMPKit

/// Minimal RTMP server handler that completes the handshake.
///
/// `@unchecked Sendable`: NIO channel handler, EventLoop-confined.
private final class FakeRTMPServerHandler: ChannelInboundHandler,
    @unchecked Sendable
{
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private var handshakeBuffer: [UInt8] = []
    private var handshakeDone = false
    private let messagesToSend: [[UInt8]]

    init(messagesToSend: [[UInt8]] = []) {
        self.messagesToSend = messagesToSend
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

            for msgBytes in messagesToSend {
                var buf = context.channel.allocator.buffer(
                    capacity: msgBytes.count
                )
                buf.writeBytes(msgBytes)
                context.writeAndFlush(
                    wrapOutboundOut(buf), promise: nil
                )
            }
        }
    }
}

/// Start a local fake RTMP server that performs handshake.
private func startFakeServer(
    group: EventLoopGroup,
    messagesToSend: [[UInt8]] = []
) async throws -> Channel {
    try await ServerBootstrap(group: group)
        .serverChannelOption(
            .socketOption(.so_reuseaddr), value: 1
        )
        .childChannelInitializer { channel in
            channel.pipeline.addHandler(
                FakeRTMPServerHandler(
                    messagesToSend: messagesToSend)
            )
        }
        .bind(host: "127.0.0.1", port: 0)
        .get()
}

/// Server that sends an invalid handshake response (bad S0 version).
///
/// `@unchecked Sendable`: NIO handler, EventLoop-confined.
private final class BadHandshakeServerHandler:
    ChannelInboundHandler, @unchecked Sendable
{
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private var handshakeBuffer: [UInt8] = []

    func channelRead(
        context: ChannelHandlerContext, data: NIOAny
    ) {
        var buffer = unwrapInboundIn(data)
        guard
            let bytes = buffer.readBytes(
                length: buffer.readableBytes)
        else { return }
        handshakeBuffer.append(contentsOf: bytes)
        guard handshakeBuffer.count >= 1537 else { return }

        // S0 with INVALID version byte (0x04 instead of 0x03)
        var s0s1s2: [UInt8] = [0x04]
        s0s1s2.append(
            contentsOf: [UInt8](repeating: 0, count: 1536))
        s0s1s2.append(
            contentsOf: [UInt8](repeating: 0, count: 1536))

        var outBuf = context.channel.allocator.buffer(
            capacity: s0s1s2.count)
        outBuf.writeBytes(s0s1s2)
        context.writeAndFlush(
            wrapOutboundOut(outBuf), promise: nil)
    }
}

private func startBadHandshakeServer(
    group: EventLoopGroup
) async throws -> Channel {
    try await ServerBootstrap(group: group)
        .serverChannelOption(
            .socketOption(.so_reuseaddr), value: 1
        )
        .childChannelInitializer { channel in
            channel.pipeline.addHandler(
                BadHandshakeServerHandler())
        }
        .bind(host: "127.0.0.1", port: 0)
        .get()
}

@Suite(
    "NIOTransport — Local Server Integration",
    .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
)
struct NIOTransportIntegrationTests {

    @Test("connect to local server succeeds")
    func connectSucceeds() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFakeServer(group: group)
        let port = try #require(server.localAddress?.port)

        let config = TransportConfiguration(connectTimeout: 5)
        let transport = NIOTransport(
            configuration: config, eventLoopGroup: group
        )
        try await transport.connect(
            host: "127.0.0.1", port: port, useTLS: false
        )

        let connected = await transport.isConnected
        #expect(connected)

        let state = await transport.state
        #expect(state == .connected)

        try await transport.close()
        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("send bytes while connected")
    func sendBytesWhileConnected() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFakeServer(group: group)
        let port = try #require(server.localAddress?.port)

        let transport = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport.connect(
            host: "127.0.0.1", port: port, useTLS: false
        )

        try await transport.send([0x01, 0x02, 0x03])

        try await transport.close()
        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("send throws when not connected")
    func sendThrowsWhenNotConnected() async throws {
        let transport = NIOTransport()

        do {
            try await transport.send([0x01])
            Issue.record("Expected TransportError.notConnected")
        } catch {
            // Expected
        }

        try? await transport.shutdown()
    }

    @Test("receive throws when not connected")
    func receiveThrowsWhenNotConnected() async throws {
        let transport = NIOTransport()

        do {
            _ = try await transport.receive()
            Issue.record("Expected TransportError.notConnected")
        } catch {
            // Expected
        }

        try? await transport.shutdown()
    }

    @Test("close while connected cleans up")
    func closeWhileConnected() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFakeServer(group: group)
        let port = try #require(server.localAddress?.port)

        let transport = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport.connect(
            host: "127.0.0.1", port: port, useTLS: false
        )

        let connectedBefore = await transport.isConnected
        #expect(connectedBefore)

        try await transport.close()

        let stateAfter = await transport.state
        #expect(stateAfter == .disconnected)

        let connectedAfter = await transport.isConnected
        #expect(!connectedAfter)

        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("shutdown while connected closes and shuts down")
    func shutdownWhileConnected() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFakeServer(group: group)
        let port = try #require(server.localAddress?.port)

        let transport = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport.connect(
            host: "127.0.0.1", port: port, useTLS: false
        )

        try await transport.shutdown()

        let state = await transport.state
        #expect(state == .disconnected)

        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("double connect throws alreadyConnected")
    func doubleConnectThrows() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFakeServer(group: group)
        let port = try #require(server.localAddress?.port)

        let transport = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport.connect(
            host: "127.0.0.1", port: port, useTLS: false
        )

        do {
            try await transport.connect(
                host: "127.0.0.1", port: port, useTLS: false
            )
            Issue.record("Expected alreadyConnected")
        } catch {
            #expect(
                error as? TransportError == .alreadyConnected
            )
        }

        try await transport.shutdown()
        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("init with shared EventLoopGroup does not shut it down")
    func sharedGroupNotShutDown() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)

        let transport = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport.shutdown()

        // Group should still be usable
        let transport2 = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport2.shutdown()

        try await group.shutdownGracefully()
    }

    @Test("init without EventLoopGroup creates own group")
    func ownGroupCreatedAndShutDown() async throws {
        let transport = NIOTransport()
        try await transport.shutdown()
    }

    @Test("receive with server-sent message delivers it")
    func receiveDelivers() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)

        let ackPayload: [UInt8] = [
            0x00, 0x26, 0x25, 0xA0
        ]
        let chunkBytes: [UInt8] =
            [
                0x02,
                0x00, 0x00, 0x00,
                0x00, 0x00, 0x04,
                0x05,
                0x00, 0x00, 0x00, 0x00
            ] + ackPayload

        let server = try await startFakeServer(
            group: group, messagesToSend: [chunkBytes]
        )
        let port = try #require(server.localAddress?.port)

        let transport = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport.connect(
            host: "127.0.0.1", port: port, useTLS: false
        )

        let msg = try await transport.receive()
        #expect(msg.typeID == RTMPMessage.typeIDWindowAckSize)

        try await transport.close()
        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("receive with buffered message returns immediately")
    func receiveBuffered() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)

        let chunkBytes: [UInt8] = [
            0x02,
            0x00, 0x00, 0x00,
            0x00, 0x00, 0x04,
            0x05,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x26, 0x25, 0xA0
        ]

        let server = try await startFakeServer(
            group: group, messagesToSend: [chunkBytes]
        )
        let port = try #require(server.localAddress?.port)

        let transport = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport.connect(
            host: "127.0.0.1", port: port, useTLS: false
        )

        // Small delay to let the server-sent message arrive
        // and get buffered
        try await Task.sleep(nanoseconds: 100_000_000)

        let msg = try await transport.receive()
        #expect(msg.payload.count == 4)

        try await transport.close()
        try await server.close()
        try await group.shutdownGracefully()
    }
}

@Suite(
    "NIOTransport — Waiting Receiver Paths",
    .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
)
struct NIOTransportWaitingReceiverTests {

    @Test("enqueueMessage delivers to waiting receiver")
    func enqueueDeliverToWaiter() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFakeServer(group: group)
        let port = try #require(server.localAddress?.port)

        let transport = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport.connect(
            host: "127.0.0.1", port: port, useTLS: false
        )

        // Start receive — suspends waiting for a message
        let receiveTask = Task {
            try await transport.receive()
        }

        // Let the receive() register its continuation
        try await Task.sleep(nanoseconds: 50_000_000)

        // Directly enqueue via internal API
        let msg = RTMPMessage(
            controlMessage: .windowAcknowledgementSize(
                1_000_000)
        )
        await transport.enqueueMessage(msg)

        let received = try await receiveTask.value
        #expect(
            received.typeID
                == RTMPMessage.typeIDWindowAckSize
        )

        try await transport.close()
        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test("handleTransportError resumes waiting receivers")
    func handleTransportErrorResumesWaiters()
        async throws
    {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startFakeServer(group: group)
        let port = try #require(server.localAddress?.port)

        let transport = NIOTransport(
            configuration: .default, eventLoopGroup: group
        )
        try await transport.connect(
            host: "127.0.0.1", port: port, useTLS: false
        )

        let receiveTask = Task {
            try await transport.receive()
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        await transport.handleTransportError(
            TransportError.connectionClosed
        )

        do {
            _ = try await receiveTask.value
            Issue.record("Expected error")
        } catch {
            // Expected — connectionClosed
        }

        try? await transport.close()
        try await server.close()
        try await group.shutdownGracefully()
    }

    @Test(
        "connect to server with bad handshake throws error"
    )
    func badHandshakeThrows() async throws {
        let group = MultiThreadedEventLoopGroup(
            numberOfThreads: 1)
        let server = try await startBadHandshakeServer(
            group: group)
        let port = try #require(server.localAddress?.port)

        let transport = NIOTransport(
            configuration: TransportConfiguration(
                connectTimeout: 5),
            eventLoopGroup: group
        )

        do {
            try await transport.connect(
                host: "127.0.0.1", port: port,
                useTLS: false
            )
            Issue.record("Expected handshake error")
        } catch {
            // Expected — bad handshake version
        }

        try? await transport.shutdown()
        try await server.close()
        try await group.shutdownGracefully()
    }
}
