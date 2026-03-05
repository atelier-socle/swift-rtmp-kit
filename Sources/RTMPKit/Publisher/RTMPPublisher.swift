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

    /// Current connection statistics snapshot.
    public var statistics: ConnectionStatistics {
        monitor.snapshot(currentTime: monotonicNow())
    }

    /// Event stream for monitoring state changes, server messages, errors.
    public let events: AsyncStream<RTMPEvent>

    internal let transport: any RTMPTransportProtocol
    internal var session = RTMPSession()
    internal var connection = RTMPConnection()
    internal var disassembler = ChunkDisassembler()
    internal var monitor = ConnectionMonitor()
    internal let eventContinuation: AsyncStream<RTMPEvent>.Continuation
    internal var messageTask: Task<Void, Never>?
    internal var currentConfiguration: RTMPConfiguration?

    /// Server information from the connect response.
    public internal(set) var serverInfo = ServerInfo()

    // MARK: - Metadata

    internal var metadataUpdater: MetadataUpdater?
    internal var hasAttemptedAdobeAuth = false

    // MARK: - Adaptive Bitrate

    internal var abrMonitor: NetworkConditionMonitor?
    internal var abrMonitorTask: Task<Void, Never>?
    internal var consecutiveDropCount: Int = 0
    internal var liveVideoBitrate: Int = 3_000_000

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

    /// The current live video bitrate as adjusted by the adaptive bitrate system.
    ///
    /// Equals the configured initial bitrate when ABR is disabled.
    public var currentVideoBitrate: Int { liveVideoBitrate }

    /// Manually override the current bitrate recommendation.
    ///
    /// Only effective when the adaptive bitrate policy is not `.disabled`.
    ///
    /// - Parameter bitrate: The target bitrate in bits per second.
    public func forceVideoBitrate(_ bitrate: Int) async {
        guard let monitor = abrMonitor else { return }
        await monitor.forceRecommendation(bitrate: bitrate)
        liveVideoBitrate = bitrate
    }

    deinit {
        messageTask?.cancel()
        abrMonitorTask?.cancel()
        eventContinuation.finish()
    }

    // MARK: - Lifecycle

    /// Connect and start publishing using an ``RTMPConfiguration``.
    ///
    /// Convenience method that unpacks the configuration into the
    /// underlying publish call. Stores the configuration for potential
    /// reconnection.
    ///
    /// - Parameter configuration: The complete streaming configuration.
    public func publish(configuration: RTMPConfiguration) async throws {
        currentConfiguration = configuration
        liveVideoBitrate = 3_000_000
        hasAttemptedAdobeAuth = false

        // Check token expiry before connecting
        if case .token(_, let expiry) = configuration.authentication {
            if TokenAuth.isExpired(expiry: expiry) {
                emitEvent(.authenticationFailed(reason: "Token expired"))
                transitionState(to: .failed(.tokenExpired))
                throw RTMPError.tokenExpired
            }
        }

        let connectionURL = buildConnectionURL(configuration)
        try await publish(
            url: connectionURL,
            streamKey: configuration.streamKey,
            chunkSize: configuration.chunkSize,
            metadata: configuration.metadata,
            enhancedRTMP: configuration.enhancedRTMP,
            flashVersion: configuration.flashVersion
        )
    }

    /// Connect and start publishing to an RTMP server.
    public func publish(
        url: String,
        streamKey: String,
        chunkSize: UInt32 = 4096,
        metadata: StreamMetadata? = nil,
        enhancedRTMP: Bool = true,
        flashVersion: String = "FMLE/3.0 (compatible; FMSc/1.0)"
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
            monitor.markConnectionStart(at: monotonicNow())
            transitionState(to: .handshaking)
            try await performRTMPConnect(
                streamKey: parsed,
                enhancedRTMP: enhancedRTMP,
                flashVersion: flashVersion
            )
            try await sendSetChunkSize(chunkSize)
            transitionState(to: .connected)
            try await performCreateStream(streamName: parsed.key)
            try await performPublish(streamName: parsed.key)
            transitionState(to: .publishing)
            await startABRMonitorIfNeeded()
            setupMetadataUpdater()

            let initialMeta = currentConfiguration?.initialMetadata ?? metadata
            if let initialMeta {
                try await metadataUpdater?.updateStreamInfo(initialMeta)
            }
            startMessageLoop()
        } catch let retryError as AdobeAuthRetryError {
            try? await transport.close()
            try await retryWithAdobeAuth(
                retryError.authQuery, originalURL: url
            )
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
        metadataUpdater = nil
        abrMonitorTask?.cancel()
        abrMonitorTask = nil
        await abrMonitor?.stop()
        abrMonitor = nil
        consecutiveDropCount = 0
        liveVideoBitrate = 3_000_000

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
        monitor.reset()
        serverInfo = ServerInfo()
        currentConfiguration = nil
        hasAttemptedAdobeAuth = false
    }

    // MARK: - Adobe Auth Retry

    private func retryWithAdobeAuth(
        _ authQuery: String, originalURL: String
    ) async throws {
        guard let config = currentConfiguration else {
            throw RTMPError.authenticationFailed("No configuration")
        }
        connection.reset()
        disassembler.reset()
        session.reset()

        let separator = originalURL.contains("?") ? "&" : "?"
        let authURL = "\(originalURL)\(separator)\(authQuery)"

        do {
            let parsed = try StreamKey(url: authURL, streamKey: config.streamKey)
            transitionState(to: .connecting)
            try await transport.connect(
                host: parsed.host, port: parsed.port, useTLS: parsed.useTLS
            )
            monitor.markConnectionStart(at: monotonicNow())
            transitionState(to: .handshaking)
            try await performRTMPConnect(
                streamKey: parsed, enhancedRTMP: config.enhancedRTMP,
                flashVersion: config.flashVersion
            )
            try await sendSetChunkSize(config.chunkSize)
            transitionState(to: .connected)
            try await performCreateStream(streamName: parsed.key)
            try await performPublish(streamName: parsed.key)
            transitionState(to: .publishing)
            await startABRMonitorIfNeeded()
            setupMetadataUpdater()

            let initialMeta = config.initialMetadata ?? config.metadata
            if let initialMeta {
                try await metadataUpdater?.updateStreamInfo(initialMeta)
            }
            startMessageLoop()
        } catch {
            emitEvent(.authenticationFailed(reason: "\(error)"))
            transitionState(to: .failed(.authenticationFailed("\(error)")))
            try? await transport.close()
            throw RTMPError.authenticationFailed("\(error)")
        }
    }

    // MARK: - Bandwidth Probing

    /// Probe the server and return the bandwidth measurement result.
    ///
    /// Runs a ``BandwidthProbe`` against the given URL to measure
    /// available uplink bandwidth before publishing.
    ///
    /// - Parameters:
    ///   - url: The RTMP server URL to probe.
    ///   - probeConfig: Probe configuration (default: `.standard`).
    /// - Returns: The probe result with bandwidth and quality measurements.
    /// - Throws: If the connection or probe fails.
    public func probeAndSelect(
        url: String,
        probeConfig: ProbeConfiguration = .standard
    ) async throws -> ProbeResult {
        let probe = BandwidthProbe(configuration: probeConfig)
        return try await probe.probe(url: url)
    }

    // MARK: - Media Sending

    /// Send a video frame.
    ///
    /// When adaptive bitrate is active and congestion is detected,
    /// non-keyframe frames may be dropped according to the configured
    /// ``FrameDroppingStrategy``.
    public func sendVideo(
        _ data: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) async throws {
        guard session.state == .publishing else {
            throw RTMPError.notPublishing
        }

        // ABR frame dropping evaluation
        if let abrMon = abrMonitor, let config = currentConfiguration {
            if let snapshot = await abrMon.currentSnapshot {
                let congestion = computeCongestionLevel(from: snapshot, configuration: config)
                let priority: FrameDroppingStrategy.FramePriority = isKeyframe ? .iFrame : .pFrame
                if config.frameDroppingStrategy.shouldDrop(
                    priority: priority,
                    consecutiveDropCount: consecutiveDropCount,
                    congestionLevel: congestion
                ) {
                    consecutiveDropCount += 1
                    await abrMon.recordDroppedFrame()
                    monitor.recordDroppedFrame()
                    return
                }
            }
            consecutiveDropCount = 0
            await abrMon.recordSentFrame()
        }

        let tagBody = FLVVideoTag.avcNALU(data, isKeyframe: isKeyframe)
        let message = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: connection.streamID ?? 1,
            timestamp: timestamp, payload: tagBody
        )
        try await sendRTMPMessage(message, chunkStreamID: .video)
        monitor.recordVideoFrameSent()
        monitor.recordBytesSent(
            UInt64(tagBody.count), at: monotonicNow()
        )

        if let abrMon = abrMonitor {
            await abrMon.recordBytesSent(tagBody.count, pendingBytes: 0)
        }
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
        monitor.recordAudioFrameSent()
        monitor.recordBytesSent(
            UInt64(tagBody.count), at: monotonicNow()
        )

        if let abrMon = abrMonitor {
            await abrMon.recordBytesSent(tagBody.count, pendingBytes: 0)
        }
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
