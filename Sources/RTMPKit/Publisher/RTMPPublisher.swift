// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// RTMP publish client — the main entry point for streaming.
///
/// Manages the complete publish lifecycle: connect → handshake → RTMP connect
/// → create stream → publish → stream audio/video → disconnect.
///
/// Uses `actor` isolation for thread safety. All media sending methods
/// (`sendAudio`, `sendVideo`) are safe to call concurrently.
///
/// ## Usage
/// ```swift
/// let publisher = RTMPPublisher()
/// try await publisher.publish(
///     url: "rtmp://live.twitch.tv/app",
///     streamKey: "live_xxx"
/// )
///
/// // Send audio/video frames…
/// try await publisher.sendAudioConfig(aacConfig)
/// try await publisher.sendVideoConfig(avcConfig)
/// try await publisher.sendAudio(aacFrame, timestamp: 0)
/// try await publisher.sendVideo(naluData, timestamp: 0, isKeyframe: true)
///
/// await publisher.disconnect()
/// ```
public actor RTMPPublisher {

    /// Current publisher state.
    public var state: RTMPPublisherState { session.state }

    /// Event stream for monitoring state changes, server messages, errors.
    public let events: AsyncStream<RTMPEvent>

    internal let transport: any RTMPTransportProtocol
    internal var session = RTMPSession()
    internal var connection = RTMPConnection()
    internal var disassembler = ChunkDisassembler()
    internal let eventContinuation: AsyncStream<RTMPEvent>.Continuation
    internal var messageTask: Task<Void, Never>?

    /// Creates a publisher with the default NIO transport.
    public init() {
        let (stream, continuation) = AsyncStream<RTMPEvent>.makeStream()
        self.events = stream
        self.eventContinuation = continuation
        self.transport = NIOTransport()
    }

    /// Creates a publisher with a custom transport (for testing).
    public init(transport: any RTMPTransportProtocol) {
        let (stream, continuation) = AsyncStream<RTMPEvent>.makeStream()
        self.events = stream
        self.eventContinuation = continuation
        self.transport = transport
    }

    deinit {
        messageTask?.cancel()
        eventContinuation.finish()
    }

    // MARK: - Lifecycle

    /// Connect and start publishing to an RTMP server.
    public func publish(
        url: String,
        streamKey: String,
        chunkSize: UInt32 = 4096,
        metadata: StreamMetadata? = nil,
        enhancedRTMP: Bool = true
    ) async throws {
        guard session.state == .idle else {
            throw RTMPError.alreadyPublishing
        }

        let parsed = try StreamKey(url: url, streamKey: streamKey)
        transitionState(to: .connecting)

        do {
            try await transport.connect(
                host: parsed.host,
                port: parsed.port,
                useTLS: parsed.useTLS
            )
            transitionState(to: .handshaking)
            try await performRTMPConnect(
                streamKey: parsed, enhancedRTMP: enhancedRTMP
            )
            try await sendSetChunkSize(chunkSize)
            transitionState(to: .connected)
            try await performCreateStream(streamName: parsed.key)
            try await performPublish(streamName: parsed.key)
            transitionState(to: .publishing)

            if let metadata {
                try await updateMetadata(metadata)
            }
            startMessageLoop()
        } catch {
            transitionState(to: .failed(mapError(error)))
            try? await transport.close()
            throw mapError(error)
        }
    }

    /// Disconnect gracefully.
    public func disconnect() async {
        messageTask?.cancel()
        messageTask = nil

        if session.state == .publishing, let streamID = connection.streamID {
            let txn1 = connection.allocateTransactionID()
            let fcUnpub = RTMPCommand.fcUnpublish(
                transactionID: Double(txn1), streamName: ""
            )
            try? await sendCommand(fcUnpub, chunkStreamID: .command)

            let txn2 = connection.allocateTransactionID()
            let del = RTMPCommand.deleteStream(
                transactionID: Double(txn2), streamID: Double(streamID)
            )
            try? await sendCommand(del, chunkStreamID: .command)
        }

        try? await transport.close()
        transitionState(to: .disconnected)
        session.reset()
        connection.reset()
        disassembler.reset()
    }

    // MARK: - Media Sending

    /// Send a video frame.
    public func sendVideo(
        _ data: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) async throws {
        guard session.state == .publishing else {
            throw RTMPError.notPublishing
        }
        let tagBody = FLVVideoTag.avcNALU(data, isKeyframe: isKeyframe)
        let message = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: connection.streamID ?? 1,
            timestamp: timestamp, payload: tagBody
        )
        try await sendRTMPMessage(message, chunkStreamID: .video)
    }

    /// Send an audio frame.
    public func sendAudio(_ data: [UInt8], timestamp: UInt32) async throws {
        guard session.state == .publishing else {
            throw RTMPError.notPublishing
        }
        let tagBody = FLVAudioTag.aacRawFrame(data)
        let message = RTMPMessage(
            typeID: RTMPMessage.typeIDAudio,
            streamID: connection.streamID ?? 1,
            timestamp: timestamp, payload: tagBody
        )
        try await sendRTMPMessage(message, chunkStreamID: .audio)
    }

    /// Send video decoder configuration (sequence header).
    public func sendVideoConfig(_ config: [UInt8]) async throws {
        guard session.state == .publishing else {
            throw RTMPError.notPublishing
        }
        let tagBody = FLVVideoTag.avcSequenceHeader(config)
        let message = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: connection.streamID ?? 1,
            timestamp: 0, payload: tagBody
        )
        try await sendRTMPMessage(message, chunkStreamID: .video)
    }

    /// Send audio decoder configuration (sequence header).
    public func sendAudioConfig(_ config: [UInt8]) async throws {
        guard session.state == .publishing else {
            throw RTMPError.notPublishing
        }
        let tagBody = FLVAudioTag.aacSequenceHeader(config)
        let message = RTMPMessage(
            typeID: RTMPMessage.typeIDAudio,
            streamID: connection.streamID ?? 1,
            timestamp: 0, payload: tagBody
        )
        try await sendRTMPMessage(message, chunkStreamID: .audio)
    }

    /// Update stream metadata.
    public func updateMetadata(_ metadata: StreamMetadata) async throws {
        guard
            session.state == .publishing
                || session.state == .connected
        else {
            throw RTMPError.notPublishing
        }
        let dataMsg = RTMPDataMessage.setDataFrame(metadata: metadata)
        let message = RTMPMessage(
            dataMessage: dataMsg, streamID: connection.streamID ?? 1
        )
        try await sendRTMPMessage(message, chunkStreamID: .command)
    }
}
