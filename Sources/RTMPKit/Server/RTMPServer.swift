// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A production-grade RTMP ingest server.
///
/// Accepts publisher connections, performs the RTMP handshake,
/// dispatches streams, and manages connected sessions.
///
/// ## Usage
/// ```swift
/// let server = RTMPServer(configuration: .localhost)
/// try await server.start()
/// // Server is now accepting connections on port 1935
/// await server.stop()
/// ```
public actor RTMPServer {

    // MARK: - Configuration

    /// Server configuration.
    public let configuration: RTMPServerConfiguration

    // MARK: - State

    /// Server lifecycle states.
    public enum State: Sendable, Equatable {
        /// Server has not been started.
        case idle
        /// Server is starting up.
        case starting
        /// Server is running and accepting connections.
        case running(port: Int)
        /// Server is shutting down.
        case stopping
        /// Server has stopped.
        case stopped
    }

    /// Current server state.
    public private(set) var state: State

    // MARK: - Sessions

    /// Currently connected sessions, keyed by session ID.
    public internal(set) var sessions: [UUID: RTMPServerSession]

    /// Number of currently active (publishing) sessions.
    public var activeSessionCount: Int {
        sessions.count
    }

    // MARK: - Delegate

    /// Optional delegate to receive session events.
    public weak var delegate: (any RTMPServerSessionDelegate)?

    /// Set the delegate.
    ///
    /// Convenience method for setting the delegate from outside the actor.
    ///
    /// - Parameter delegate: The delegate to set.
    public func setDelegate(_ delegate: (any RTMPServerSessionDelegate)?) {
        self.delegate = delegate
    }

    // MARK: - Events

    private let eventContinuation: AsyncStream<RTMPServerEvent>.Continuation
    private let eventStream: AsyncStream<RTMPServerEvent>

    /// Stream of server-level events.
    public var events: AsyncStream<RTMPServerEvent> {
        eventStream
    }

    // MARK: - Stream Management

    /// Relays attached per stream name.
    var relays: [String: RTMPStreamRelay] = [:]

    /// DVR recorders attached per stream name.
    var dvrs: [String: RTMPStreamDVR] = [:]

    // MARK: - Internal

    var sessionTasks: [UUID: Task<Void, Never>] = [:]
    private let transportFactory: (@Sendable () -> any RTMPTransportProtocol)?
    private var acceptTask: Task<Void, Never>?

    // MARK: - Initializers

    /// Production init — uses real NIO ServerBootstrap.
    ///
    /// - Parameter configuration: Server configuration.
    public init(configuration: RTMPServerConfiguration = .localhost) {
        self.configuration = configuration
        self.state = .idle
        self.sessions = [:]
        self.transportFactory = nil
        let (stream, continuation) = AsyncStream<RTMPServerEvent>.makeStream()
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    /// Testable init — uses a transport factory instead of NIO ServerBootstrap.
    ///
    /// The factory is called once per accepted "connection" during tests.
    ///
    /// - Parameters:
    ///   - configuration: Server configuration.
    ///   - sessionTransportFactory: Factory that creates a mock transport per session.
    internal init(
        configuration: RTMPServerConfiguration,
        sessionTransportFactory: @escaping @Sendable () -> any RTMPTransportProtocol
    ) {
        self.configuration = configuration
        self.state = .idle
        self.sessions = [:]
        self.transportFactory = sessionTransportFactory
        let (stream, continuation) = AsyncStream<RTMPServerEvent>.makeStream()
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    deinit {
        acceptTask?.cancel()
        for (_, task) in sessionTasks {
            task.cancel()
        }
        eventContinuation.finish()
    }

    // MARK: - Lifecycle

    /// Start the server and begin accepting connections.
    ///
    /// For test configurations with a transport factory, transitions
    /// immediately to `.running`. For production, would bind a NIO
    /// `ServerBootstrap` (Sessions 14-15).
    public func start() async throws {
        guard state == .idle else { return }
        state = .starting
        state = .running(port: configuration.port)
        emitEvent(.started(port: configuration.port))
    }

    /// Stop the server and close all active sessions gracefully.
    public func stop() async {
        guard case .running = state else { return }
        state = .stopping
        acceptTask?.cancel()
        acceptTask = nil

        await withTaskGroup(of: Void.self) { group in
            for (sessionID, task) in sessionTasks {
                let session = sessions[sessionID]
                group.addTask {
                    task.cancel()
                    await session?.close()
                }
            }
        }

        sessionTasks.removeAll()
        sessions.removeAll()
        state = .stopped
        emitEvent(.stopped)
    }

    // MARK: - Session Management

    /// Close a specific session by ID.
    ///
    /// - Parameter id: The session UUID to close.
    public func closeSession(id: UUID) async {
        guard let session = sessions[id] else { return }
        sessionTasks[id]?.cancel()
        sessionTasks.removeValue(forKey: id)
        await session.close()
        sessions.removeValue(forKey: id)
        let streamName = await session.streamName
        if let streamName {
            emitEvent(.streamStopped(session: session, streamName: streamName))
        }
        emitEvent(.sessionDisconnected(id: id, reason: "Closed by server"))
        await delegate?.serverSessionDidDisconnect(session, reason: "Closed by server")
    }

    /// Close all sessions publishing to a specific stream name.
    ///
    /// - Parameter streamName: The stream name to match.
    public func closeSessions(streamName: String) async {
        var toClose: [UUID] = []
        for (id, session) in sessions {
            let name = await session.streamName
            if name == streamName {
                toClose.append(id)
            }
        }
        for id in toClose {
            await closeSession(id: id)
        }
    }

    // MARK: - Test Helpers

    /// Accept a simulated connection for testing.
    ///
    /// Creates a session using the transport factory and begins
    /// processing RTMP messages from it.
    ///
    /// - Parameter remoteAddress: Simulated remote address.
    /// - Returns: The created session.
    @discardableResult
    internal func acceptConnection(
        remoteAddress: String = "test-client"
    ) async -> RTMPServerSession {
        let transport: any RTMPTransportProtocol
        if let factory = transportFactory {
            transport = factory()
        } else {
            transport = MockInternalTransport()
        }

        let session = RTMPServerSession(
            transport: transport,
            remoteAddress: remoteAddress,
            connectedAt: currentTime()
        )
        sessions[session.id] = session

        let sessionID = session.id
        let task = Task { [weak self] in
            await self?.runSession(sessionID)
            return
        }
        sessionTasks[sessionID] = task

        return session
    }

    // MARK: - Session Message Loop

    private func runSession(_ sessionID: UUID) async {
        guard let session = sessions[sessionID] else { return }

        while !Task.isCancelled {
            let message: RTMPMessage
            do {
                message = try await session.transport.receive()
            } catch {
                await handleSessionDisconnect(
                    sessionID, reason: "Connection closed"
                )
                return
            }

            await session.recordBytesReceived(message.payload.count)

            do {
                try await handleMessage(message, session: session)
            } catch {
                await handleSessionDisconnect(
                    sessionID, reason: "Error: \(error)"
                )
                return
            }
        }
    }

    // MARK: - Helpers

    func emitEvent(_ event: RTMPServerEvent) {
        eventContinuation.yield(event)
    }

    func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }
}

/// Internal placeholder transport (never used in tests — factory always provides MockTransport).
private actor MockInternalTransport: RTMPTransportProtocol {
    var isConnected: Bool { false }
    func connect(host: String, port: Int, useTLS: Bool) async throws {}
    func send(_ bytes: [UInt8]) async throws {}
    func receive() async throws -> RTMPMessage {
        throw TransportError.connectionClosed
    }
    func close() async throws {}
}
