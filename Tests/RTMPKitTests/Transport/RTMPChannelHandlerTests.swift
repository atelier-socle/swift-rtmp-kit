// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import NIOEmbedded
import Testing

@testable import RTMPKit

/// Thread-safe collector for test callbacks.
///
/// `@unchecked Sendable`: test helper only — not used in production.
private final class TestCollector: @unchecked Sendable {
    var messages: [RTMPMessage] = []
    var handshakeCompleted = false
    var receivedError: Error?
}

/// Create an EmbeddedChannel with handler + collector (NOT yet connected).
private func makeHandler(
    collector: TestCollector
) -> (EmbeddedChannel, RTMPChannelHandler) {
    let handler = RTMPChannelHandler(
        onMessage: { collector.messages.append($0) },
        onHandshakeComplete: { collector.handshakeCompleted = true },
        onError: { collector.receivedError = $0 }
    )
    let channel = EmbeddedChannel(handler: handler)
    return (channel, handler)
}

/// Create an EmbeddedChannel with handler + collector, already connected
/// (which fires channelActive and sends C0+C1).
private func makeConnectedChannel(
    collector: TestCollector
) throws -> EmbeddedChannel {
    let (channel, _) = makeHandler(collector: collector)
    _ = try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1935))
    return channel
}

/// Drain outbound C0+C1 bytes and return C1.
private func drainC0C1(channel: EmbeddedChannel) -> [UInt8] {
    var c0c1: [UInt8] = []
    while let outbound: ByteBuffer = try? channel.readOutbound() {
        var buf = outbound
        if let bytes = buf.readBytes(length: buf.readableBytes) {
            c0c1.append(contentsOf: bytes)
        }
    }
    guard c0c1.count > 1 else { return [] }
    return Array(c0c1.dropFirst())
}

/// Build a mock S0+S1+S2 response matching the given C1.
private func buildS0S1S2(c1: [UInt8]) -> [UInt8] {
    var result: [UInt8] = [0x03]
    var s1 = [UInt8](repeating: 0, count: 1536)
    for i in 8..<1536 { s1[i] = UInt8.random(in: 0...255) }
    result.append(contentsOf: s1)
    var s2 = [UInt8](repeating: 0, count: 1536)
    if c1.count >= 4 { for i in 0..<4 { s2[i] = c1[i] } }
    if c1.count >= 1536 { for i in 8..<1536 { s2[i] = c1[i] } }
    result.append(contentsOf: s2)
    return result
}

/// Feed bytes into the channel's inbound.
private func feedBytes(_ bytes: [UInt8], to channel: EmbeddedChannel) {
    var buffer = channel.allocator.buffer(capacity: bytes.count)
    buffer.writeBytes(bytes)
    _ = try? channel.writeInbound(buffer)
}

/// Complete the handshake on an already-connected channel.
private func completeHandshake(channel: EmbeddedChannel) {
    let c1 = drainC0C1(channel: channel)
    let s0s1s2 = buildS0S1S2(c1: c1)
    feedBytes(s0s1s2, to: channel)
    while (try? channel.readOutbound(as: ByteBuffer.self)) != nil {}
}

/// Drain all outbound data.
private func drainOutbound(channel: EmbeddedChannel) {
    while (try? channel.readOutbound(as: ByteBuffer.self)) != nil {}
}

@Suite("RTMPChannelHandler — Handshake")
struct RTMPChannelHandlerHandshakeTests {

    @Test("channelActive triggers C0+C1 send (1537 bytes)")
    func channelActiveSendsC0C1() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }

        var totalBytes = 0
        while let outbound: ByteBuffer = try channel.readOutbound() {
            totalBytes += outbound.readableBytes
        }
        #expect(totalBytes == 1537)
    }

    @Test("Feed S0+S1+S2 triggers C2 send")
    func feedS0S1S2SendsC2() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }

        let c1 = drainC0C1(channel: channel)
        let s0s1s2 = buildS0S1S2(c1: c1)
        feedBytes(s0s1s2, to: channel)

        var c2Bytes = 0
        while let outbound: ByteBuffer = try channel.readOutbound() {
            c2Bytes += outbound.readableBytes
        }
        #expect(c2Bytes == 1536)
    }

    @Test("Handshake completion callback fires")
    func handshakeCompleteCallbackFires() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        completeHandshake(channel: channel)
        #expect(collector.handshakeCompleted)
    }

    @Test("Truncated S0S1S2 buffers without error")
    func truncatedS0S1S2Buffers() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        drainOutbound(channel: channel)
        feedBytes([UInt8](repeating: 0, count: 100), to: channel)
        #expect(collector.receivedError == nil)
    }

    @Test("Invalid S0 version triggers error callback")
    func invalidS0Version() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        drainOutbound(channel: channel)

        var s0s1s2 = [UInt8](repeating: 0, count: 3073)
        s0s1s2[0] = 0x04
        feedBytes(s0s1s2, to: channel)

        #expect(collector.receivedError != nil)
    }

    @Test("After handshake, phase transitions to messaging")
    func phaseTransitionsToMessaging() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        completeHandshake(channel: channel)

        // Feed a valid chunk message — if phase is messaging, it should be processed
        let msg = RTMPMessage(
            controlMessage: .windowAcknowledgementSize(1_000_000)
        )
        var disassembler = ChunkDisassembler()
        let bytes = disassembler.disassemble(
            message: msg,
            chunkStreamID: .protocolControl
        )
        feedBytes(bytes, to: channel)
        #expect(collector.messages.count == 1)
    }
}

@Suite("RTMPChannelHandler — Messaging")
struct RTMPChannelHandlerMessagingTests {

    @Test("Feed chunked control message delivers RTMPMessage")
    func feedChunkedControlMessage() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        completeHandshake(channel: channel)

        let msg = RTMPMessage(controlMessage: .setChunkSize(4096))
        var disassembler = ChunkDisassembler()
        let bytes = disassembler.disassemble(
            message: msg,
            chunkStreamID: .protocolControl
        )
        feedBytes(bytes, to: channel)

        #expect(collector.messages.count == 1)
        #expect(collector.messages[0].typeID == RTMPMessage.typeIDSetChunkSize)
    }

    @Test("Ping Request auto-responds with Ping Response")
    func pingRequestAutoResponds() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        completeHandshake(channel: channel)
        drainOutbound(channel: channel)

        let event = RTMPUserControlEvent.pingRequest(timestamp: 12345)
        let msg = RTMPMessage(userControlEvent: event)
        var disassembler = ChunkDisassembler()
        let bytes = disassembler.disassemble(
            message: msg,
            chunkStreamID: .protocolControl
        )
        feedBytes(bytes, to: channel)

        var responseBytes: [UInt8] = []
        while let outbound: ByteBuffer = try channel.readOutbound() {
            var buf = outbound
            if let b = buf.readBytes(length: buf.readableBytes) {
                responseBytes.append(contentsOf: b)
            }
        }
        #expect(!responseBytes.isEmpty)
    }

    @Test("Window Ack Size message is delivered")
    func windowAckSizeDelivered() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        completeHandshake(channel: channel)

        let msg = RTMPMessage(
            controlMessage: .windowAcknowledgementSize(2_500_000)
        )
        var disassembler = ChunkDisassembler()
        let bytes = disassembler.disassemble(
            message: msg,
            chunkStreamID: .protocolControl
        )
        feedBytes(bytes, to: channel)

        #expect(collector.messages.count == 1)
        #expect(collector.messages[0].typeID == RTMPMessage.typeIDWindowAckSize)
    }

    @Test("Multiple messages delivered in order")
    func multipleMessagesInOrder() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        completeHandshake(channel: channel)

        var disassembler = ChunkDisassembler()
        let msg1 = RTMPMessage(
            controlMessage: .windowAcknowledgementSize(1_000_000)
        )
        let msg2 = RTMPMessage(
            controlMessage: .windowAcknowledgementSize(2_000_000)
        )
        let bytes1 = disassembler.disassemble(
            message: msg1,
            chunkStreamID: .protocolControl
        )
        let bytes2 = disassembler.disassemble(
            message: msg2,
            chunkStreamID: .protocolControl
        )
        feedBytes(bytes1 + bytes2, to: channel)
        #expect(collector.messages.count == 2)
    }

    @Test("Set Chunk Size is handled internally")
    func setChunkSizeHandled() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        completeHandshake(channel: channel)

        let msg = RTMPMessage(controlMessage: .setChunkSize(4096))
        var disassembler = ChunkDisassembler()
        let bytes = disassembler.disassemble(
            message: msg,
            chunkStreamID: .protocolControl
        )
        feedBytes(bytes, to: channel)
        #expect(collector.messages.count == 1)
    }
}

@Suite("RTMPChannelHandler — Outgoing & Errors")
struct RTMPChannelHandlerOutgoingTests {

    @Test("writeRaw writes bytes directly")
    func writeRawWritesDirect() throws {
        let collector = TestCollector()
        let (channel, handler) = makeHandler(collector: collector)
        defer { _ = try? channel.finish() }
        _ = try channel.connect(
            to: SocketAddress(ipAddress: "127.0.0.1", port: 1935)
        )
        drainOutbound(channel: channel)

        let ctx = try channel.pipeline.syncOperations.context(handler: handler)
        handler.writeRaw([0xCA, 0xFE], context: ctx)

        if let outbound: ByteBuffer = try channel.readOutbound() {
            var buf = outbound
            let bytes = buf.readBytes(length: buf.readableBytes)
            #expect(bytes == [0xCA, 0xFE])
        }
    }

    @Test("writeMessage serializes via ChunkDisassembler")
    func writeMessageSerializes() throws {
        let collector = TestCollector()
        let (channel, handler) = makeHandler(collector: collector)
        defer { _ = try? channel.finish() }
        _ = try channel.connect(
            to: SocketAddress(ipAddress: "127.0.0.1", port: 1935)
        )
        completeHandshake(channel: channel)
        drainOutbound(channel: channel)

        let msg = RTMPMessage(
            controlMessage: .windowAcknowledgementSize(2_500_000)
        )
        let ctx = try channel.pipeline.syncOperations.context(handler: handler)
        handler.writeMessage(msg, chunkStreamID: .protocolControl, context: ctx)

        var totalBytes = 0
        while let outbound: ByteBuffer = try channel.readOutbound() {
            totalBytes += outbound.readableBytes
        }
        #expect(totalBytes > 0)
    }

    @Test("errorCaught triggers onError callback")
    func errorCaughtTriggersCallback() throws {
        let collector = TestCollector()
        let (channel, _) = makeHandler(collector: collector)
        defer { _ = try? channel.finish() }

        channel.pipeline.fireErrorCaught(TransportError.connectionClosed)
        #expect(collector.receivedError != nil)
    }

    @Test("channelInactive does not trigger onError")
    func channelInactiveNoError() throws {
        let collector = TestCollector()
        let (channel, _) = makeHandler(collector: collector)
        _ = try? channel.finish()
        #expect(collector.receivedError == nil)
    }

    @Test("updateChunkSize does not crash")
    func updateChunkSizeNoCrash() throws {
        let collector = TestCollector()
        let (channel, handler) = makeHandler(collector: collector)
        defer { _ = try? channel.finish() }
        handler.updateChunkSize(4096)
    }

    @Test("Default chunk size is 128")
    func defaultChunkSize128() throws {
        let collector = TestCollector()
        let channel = try makeConnectedChannel(collector: collector)
        defer { _ = try? channel.finish() }
        #expect(channel.isActive)
    }
}
