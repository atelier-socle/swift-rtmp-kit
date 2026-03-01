// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import NIOPosix
import NIOSSL

/// NIO-based RTMP transport for TCP and RTMPS connections.
///
/// Manages the NIO ``EventLoopGroup``, channel bootstrap, and TLS
/// configuration. The channel pipeline includes ``RTMPChannelHandler``
/// for chunk framing and optional NIOSSL for RTMPS.
public actor NIOTransport: RTMPTransportProtocol {

    /// Connection state.
    public enum ConnectionState: Sendable {
        /// Not connected.
        case disconnected
        /// Connection in progress.
        case connecting
        /// Connected and ready.
        case connected
        /// Disconnection in progress.
        case disconnecting
    }

    /// Current connection state.
    public private(set) var state: ConnectionState = .disconnected

    /// Transport configuration.
    private let configuration: TransportConfiguration

    /// NIO event loop group.
    private let eventLoopGroup: EventLoopGroup

    /// Whether we own the event loop group (and should shut it down).
    private let ownsEventLoopGroup: Bool

    /// Active NIO channel.
    private var channel: Channel?

    /// Buffered messages not yet consumed by receive().
    private var pendingMessages: [RTMPMessage] = []

    /// Continuations waiting for the next message.
    private var waitingReceivers: [CheckedContinuation<RTMPMessage, Error>] = []

    /// Whether the handshake has completed.
    private var handshakeCompleted = false

    /// Error from the handshake phase.
    private var handshakeError: Error?

    /// Continuation for handshake completion.
    private var handshakeContinuation: CheckedContinuation<Void, Error>?

    /// Whether the transport is currently connected.
    public var isConnected: Bool {
        state == .connected
    }

    /// Creates a transport with optional shared EventLoopGroup.
    ///
    /// If no group is provided, creates a dedicated
    /// ``MultiThreadedEventLoopGroup`` with 1 thread (RTMP is single-connection).
    ///
    /// - Parameters:
    ///   - configuration: Transport configuration (default: `.default`).
    ///   - eventLoopGroup: Shared event loop group (default: creates own).
    public init(
        configuration: TransportConfiguration = .default,
        eventLoopGroup: EventLoopGroup? = nil
    ) {
        self.configuration = configuration
        if let group = eventLoopGroup {
            self.eventLoopGroup = group
            self.ownsEventLoopGroup = false
        } else {
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            self.ownsEventLoopGroup = true
        }
    }

    // MARK: - RTMPTransportProtocol

    /// Connect to an RTMP server.
    ///
    /// Sets up the NIO channel pipeline with optional TLS and the
    /// ``RTMPChannelHandler`` for RTMP framing. Completes after
    /// the RTMP handshake finishes.
    ///
    /// - Parameters:
    ///   - host: Server hostname or IP.
    ///   - port: Server port.
    ///   - useTLS: Whether to use TLS (RTMPS).
    /// - Throws: ``TransportError`` on failure.
    public func connect(host: String, port: Int, useTLS: Bool) async throws {
        guard state == .disconnected else {
            throw TransportError.alreadyConnected
        }

        state = .connecting
        handshakeCompleted = false
        handshakeError = nil

        do {
            let ch = try await bootstrapChannel(
                host: host,
                port: port,
                useTLS: useTLS
            )
            self.channel = ch
            try await waitForHandshake()
            state = .connected
        } catch {
            state = .disconnected
            channel = nil
            throw error
        }
    }

    /// Send raw bytes to the server.
    ///
    /// - Parameter bytes: The bytes to send.
    /// - Throws: ``TransportError/notConnected`` if not connected.
    public func send(_ bytes: [UInt8]) async throws {
        guard state == .connected, let channel = channel else {
            throw TransportError.notConnected
        }
        var buffer = channel.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        try await channel.writeAndFlush(buffer)
    }

    /// Receive the next complete RTMP message.
    ///
    /// Returns a buffered message if available, otherwise suspends until
    /// the channel handler delivers one.
    ///
    /// - Returns: The next message from the server.
    /// - Throws: ``TransportError`` on connection close or error.
    public func receive() async throws -> RTMPMessage {
        guard state == .connected else {
            throw TransportError.notConnected
        }
        if !pendingMessages.isEmpty {
            return pendingMessages.removeFirst()
        }
        return try await withCheckedThrowingContinuation { cont in
            self.waitingReceivers.append(cont)
        }
    }

    /// Close the connection gracefully.
    public func close() async throws {
        guard state == .connected || state == .connecting else {
            return
        }

        state = .disconnecting

        let err = TransportError.connectionClosed
        for waiter in waitingReceivers {
            waiter.resume(throwing: err)
        }
        waitingReceivers.removeAll()
        pendingMessages.removeAll()

        if let channel = channel {
            try await channel.close()
            self.channel = nil
        }

        state = .disconnected
    }

    /// Shut down the transport, releasing the EventLoopGroup if owned.
    public func shutdown() async throws {
        if state == .connected || state == .connecting {
            try await close()
        }
        if ownsEventLoopGroup {
            try await eventLoopGroup.shutdownGracefully()
        }
    }

    // MARK: - Internal — Called by Channel Handler via Task

    /// Enqueue a message from the channel handler.
    func enqueueMessage(_ message: RTMPMessage) {
        if let waiter = waitingReceivers.first {
            waitingReceivers.removeFirst()
            waiter.resume(returning: message)
        } else {
            pendingMessages.append(message)
        }
    }

    /// Signal that the handshake completed successfully.
    func completeHandshake() {
        handshakeCompleted = true
        handshakeContinuation?.resume()
        handshakeContinuation = nil
    }

    /// Signal an error from the channel handler.
    func handleTransportError(_ error: Error) {
        if let cont = handshakeContinuation {
            handshakeError = error
            cont.resume(throwing: error)
            handshakeContinuation = nil
        } else {
            for waiter in waitingReceivers {
                waiter.resume(throwing: error)
            }
            waitingReceivers.removeAll()
        }
    }

    // MARK: - Private

    private func waitForHandshake() async throws {
        if handshakeCompleted { return }
        if let error = handshakeError { throw error }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            if self.handshakeCompleted {
                cont.resume()
            } else if let error = self.handshakeError {
                cont.resume(throwing: error)
            } else {
                self.handshakeContinuation = cont
            }
        }
    }

    private func bootstrapChannel(
        host: String,
        port: Int,
        useTLS: Bool
    ) async throws -> Channel {
        let transport = self
        let tlsMinVersion = configuration.tlsMinimumVersion
        let connectTimeoutSecs = Int64(configuration.connectTimeout)

        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .connectTimeout(.seconds(connectTimeoutSecs))
            .channelInitializer { channel in
                let handler = RTMPChannelHandler(
                    onMessage: { message in
                        Task { await transport.enqueueMessage(message) }
                    },
                    onHandshakeComplete: {
                        Task { await transport.completeHandshake() }
                    },
                    onError: { error in
                        Task { await transport.handleTransportError(error) }
                    }
                )

                do {
                    if useTLS {
                        let tlsConfig = TLSConfiguration.rtmps(
                            minimumVersion: tlsMinVersion
                        )
                        let sslContext = try NIOSSLContext(configuration: tlsConfig)
                        let sslHandler = try NIOSSLClientHandler(
                            context: sslContext,
                            serverHostname: host
                        )
                        try channel.pipeline.syncOperations.addHandler(sslHandler)
                    }
                    try channel.pipeline.syncOperations.addHandler(handler)
                    return channel.eventLoop.makeSucceededVoidFuture()
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }

        return try await bootstrap.connect(host: host, port: port).get()
    }
}
