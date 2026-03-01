// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

/// NIO channel handler for RTMP message framing.
///
/// Handles two phases:
/// 1. **Handshake phase**: Raw byte exchange (C0/C1/C2 ↔ S0/S1/S2)
/// 2. **Message phase**: Chunk-based framing using ``ChunkAssembler``/``ChunkDisassembler``
///
/// Incoming data flows through chunk assembly to produce complete ``RTMPMessage``s.
/// Outgoing ``RTMPMessage``s are chunk-disassembled into bytes for the wire.
///
/// - Note: NIO channel handlers are confined to their EventLoop thread,
///   ensuring single-threaded access to mutable state.
///
/// `@unchecked Sendable`: NIO channel handlers are confined to their
/// EventLoop and never accessed from multiple threads concurrently.
/// This is the standard NIO pattern for strict concurrency compliance.
internal final class RTMPChannelHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    /// Handler phase.
    enum Phase {
        /// Handshake byte exchange (C0/C1/C2).
        case handshake
        /// RTMP message framing via chunks.
        case messaging
    }

    /// Current phase.
    private var phase: Phase = .handshake

    /// Handshake state machine.
    private var handshake = RTMPHandshake()

    /// Chunk assembler for incoming data.
    private var assembler = ChunkAssembler()

    /// Chunk disassembler for outgoing messages.
    private var disassembler = ChunkDisassembler()

    /// Buffer for accumulating incoming handshake bytes.
    private var handshakeBuffer: [UInt8] = []

    /// Callback for delivering complete messages to the transport layer.
    private let onMessage: @Sendable (RTMPMessage) -> Void

    /// Callback for handshake completion.
    private let onHandshakeComplete: @Sendable () -> Void

    /// Callback for errors.
    private let onError: @Sendable (Error) -> Void

    /// Expected size for S0+S1+S2 (1 + 1536 + 1536 = 3073).
    private static let s0s1s2Size = 1 + HandshakeBytes.packetSize * 2

    /// Creates a channel handler with callbacks for events.
    ///
    /// - Parameters:
    ///   - onMessage: Called when a complete RTMP message is assembled.
    ///   - onHandshakeComplete: Called when the handshake finishes.
    ///   - onError: Called when an error occurs.
    init(
        onMessage: @escaping @Sendable (RTMPMessage) -> Void,
        onHandshakeComplete: @escaping @Sendable () -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) {
        self.onMessage = onMessage
        self.onHandshakeComplete = onHandshakeComplete
        self.onError = onError
    }

    // MARK: - ChannelInboundHandler

    /// Called when the channel becomes active — initiates handshake.
    func channelActive(context: ChannelHandlerContext) {
        do {
            let c0c1 = try handshake.generateC0C1()
            writeRaw(c0c1, context: context)
        } catch {
            onError(error)
            context.close(promise: nil)
        }
    }

    /// Called when data arrives from the server.
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else {
            return
        }

        switch phase {
        case .handshake:
            handleHandshakeData(bytes, context: context)
        case .messaging:
            handleMessageData(bytes, context: context)
        }
    }

    /// Called when the channel becomes inactive.
    func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }

    /// Called when an error is caught in the pipeline.
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        onError(error)
        context.close(promise: nil)
    }

    // MARK: - Outgoing

    /// Serialize and write an RTMP message to the channel.
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - chunkStreamID: The chunk stream ID to use.
    ///   - context: The channel handler context.
    func writeMessage(
        _ message: RTMPMessage,
        chunkStreamID: ChunkStreamID,
        context: ChannelHandlerContext
    ) {
        let bytes = disassembler.disassemble(
            message: message,
            chunkStreamID: chunkStreamID
        )
        writeRaw(bytes, context: context)
    }

    /// Write raw bytes to the channel (for handshake phase).
    ///
    /// - Parameters:
    ///   - bytes: The bytes to write.
    ///   - context: The channel handler context.
    func writeRaw(_ bytes: [UInt8], context: ChannelHandlerContext) {
        var buffer = context.channel.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        context.writeAndFlush(wrapOutboundOut(buffer), promise: nil)
    }

    /// Update the chunk size for both assembler and disassembler.
    ///
    /// - Parameter size: The new chunk size.
    func updateChunkSize(_ size: UInt32) {
        assembler.setChunkSize(size)
        disassembler.setChunkSize(size)
    }

    // MARK: - Private — Handshake

    private func handleHandshakeData(
        _ bytes: [UInt8],
        context: ChannelHandlerContext
    ) {
        handshakeBuffer.append(contentsOf: bytes)

        guard handshakeBuffer.count >= Self.s0s1s2Size else {
            return
        }

        let s0s1s2 = Array(handshakeBuffer.prefix(Self.s0s1s2Size))
        let leftover = Array(handshakeBuffer.dropFirst(Self.s0s1s2Size))

        do {
            try handshake.processS0S1S2(s0s1s2)
            let c2 = try handshake.generateC2()
            writeRaw(c2, context: context)
            phase = .messaging
            handshakeBuffer = []
            onHandshakeComplete()
            if !leftover.isEmpty {
                handleMessageData(leftover, context: context)
            }
        } catch {
            onError(error)
            context.close(promise: nil)
        }
    }

    // MARK: - Private — Messaging

    private func handleMessageData(
        _ bytes: [UInt8],
        context: ChannelHandlerContext
    ) {
        do {
            let messages = try assembler.process(bytes: bytes)
            for message in messages {
                handleInternalMessage(message, context: context)
                onMessage(message)
            }
        } catch {
            onError(error)
        }
    }

    private func handleInternalMessage(
        _ message: RTMPMessage,
        context: ChannelHandlerContext
    ) {
        switch message.typeID {
        case RTMPMessage.typeIDSetChunkSize:
            if let ctrl = try? RTMPControlMessage.decode(
                typeID: message.typeID,
                payload: message.payload
            ) {
                if case .setChunkSize(let size) = ctrl {
                    updateChunkSize(size)
                }
            }
        case RTMPMessage.typeIDUserControl:
            if let event = try? RTMPUserControlEvent.decode(from: message.payload) {
                if case .pingRequest(let timestamp) = event {
                    let response = RTMPMessage(
                        userControlEvent: .pingResponse(timestamp: timestamp)
                    )
                    writeMessage(
                        response,
                        chunkStreamID: .protocolControl,
                        context: context
                    )
                }
            }
        default:
            break
        }
    }
}
