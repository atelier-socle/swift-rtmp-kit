// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch

/// Errors specific to ``MultiPublisher`` operations.
public enum MultiPublisherError: Error, Sendable, Equatable {
    /// No destination with this ID exists.
    case destinationNotFound(String)
    /// A destination with this ID already exists.
    case destinationAlreadyExists(String)
}

/// Multi-destination RTMP publisher.
///
/// Orchestrates N independent ``RTMPPublisher`` instances, each streaming
/// to a separate RTMP server. Destinations can be added and removed
/// while streaming (hot add/remove). Each destination is failure-isolated —
/// if one fails, the others continue unaffected.
///
/// ## Usage
/// ```swift
/// let multi = MultiPublisher()
/// try multi.addDestination(
///     PublishDestination(id: "twitch", url: "rtmp://live.twitch.tv/app", streamKey: "key1")
/// )
/// try multi.addDestination(
///     PublishDestination(id: "youtube", url: "rtmps://a.rtmp.youtube.com/live2", streamKey: "key2")
/// )
/// await multi.startAll()
///
/// // Send A/V to all active destinations
/// await multi.sendVideo(naluData, timestamp: 0, isKeyframe: true)
/// await multi.sendAudio(aacFrame, timestamp: 0)
///
/// await multi.stopAll()
/// ```
public actor MultiPublisher {

    /// Factory closure for creating transports per destination.
    public typealias TransportFactory =
        @Sendable (RTMPConfiguration) -> any RTMPTransportProtocol

    // MARK: - Public State

    /// Current state of each destination, keyed by destination ID.
    public private(set) var destinationStates: [String: DestinationState] = [:]

    /// Aggregated statistics snapshot. Updated after every media send call.
    public private(set) var statistics = MultiPublisherStatistics()

    /// Stream of (destinationID, RTMPEvent) pairs — events from all destinations.
    public let events: AsyncStream<(String, RTMPEvent)>

    // MARK: - Private State

    private var handles: [String: DestinationHandle] = [:]
    private let transportFactory: TransportFactory
    private let eventContinuation: AsyncStream<(String, RTMPEvent)>.Continuation

    // MARK: - Internal Types

    private struct DestinationHandle {
        let destination: PublishDestination
        let publisher: RTMPPublisher
        var eventTask: Task<Void, Never>?
    }

    // MARK: - Init

    /// Creates a multi-publisher with the default NIO transport.
    public init() {
        let (stream, continuation) = AsyncStream<(String, RTMPEvent)>.makeStream()
        self.events = stream
        self.eventContinuation = continuation
        self.transportFactory = { _ in NIOTransport() }
    }

    /// Creates a multi-publisher with a custom transport factory.
    ///
    /// Use this in tests to inject ``MockTransport`` per destination.
    ///
    /// - Parameter transportFactory: Closure that creates a transport for each destination.
    public init(transportFactory: @escaping TransportFactory) {
        let (stream, continuation) = AsyncStream<(String, RTMPEvent)>.makeStream()
        self.events = stream
        self.eventContinuation = continuation
        self.transportFactory = transportFactory
    }

    deinit {
        for handle in handles.values {
            handle.eventTask?.cancel()
        }
        eventContinuation.finish()
    }

    // MARK: - Destination Management

    /// Add a destination. Can be called before or during streaming.
    ///
    /// The destination starts in ``DestinationState/idle`` state. Call
    /// ``start(id:)`` or ``startAll()`` to begin publishing.
    ///
    /// - Parameter destination: The destination to add.
    /// - Throws: ``MultiPublisherError/destinationAlreadyExists(_:)`` if a destination
    ///   with the same ID already exists.
    public func addDestination(_ destination: PublishDestination) throws {
        guard handles[destination.id] == nil else {
            throw MultiPublisherError.destinationAlreadyExists(destination.id)
        }
        let transport = transportFactory(destination.configuration)
        let publisher = RTMPPublisher(transport: transport)
        handles[destination.id] = DestinationHandle(
            destination: destination, publisher: publisher
        )
        destinationStates[destination.id] = .idle
    }

    /// Remove a destination. Stops it first if currently active.
    ///
    /// - Parameter id: The destination ID to remove.
    /// - Throws: ``MultiPublisherError/destinationNotFound(_:)`` if the ID is not found.
    public func removeDestination(id: String) async throws {
        guard var handle = handles[id] else {
            throw MultiPublisherError.destinationNotFound(id)
        }
        handle.eventTask?.cancel()
        handle.eventTask = nil
        if let state = destinationStates[id], state.isActive {
            await handle.publisher.disconnect()
        }
        handles.removeValue(forKey: id)
        destinationStates.removeValue(forKey: id)
    }

    // MARK: - Lifecycle

    /// Start all destinations that are currently ``DestinationState/idle``.
    public func startAll() async {
        let idleIDs =
            destinationStates
            .filter { $0.value == .idle }
            .map(\.key)

        await withTaskGroup(of: Void.self) { group in
            for id in idleIDs {
                group.addTask { [self] in
                    try? await self.start(id: id)
                }
            }
        }
    }

    /// Start a specific destination by ID.
    ///
    /// - Parameter id: The destination ID to start.
    /// - Throws: ``MultiPublisherError/destinationNotFound(_:)`` if the ID is not found.
    public func start(id: String) async throws {
        guard let handle = handles[id] else {
            throw MultiPublisherError.destinationNotFound(id)
        }

        destinationStates[id] = .connecting

        let publisher = handle.publisher
        let config = handle.destination.configuration

        do {
            try await publisher.publish(configuration: config)
            destinationStates[id] = .streaming
        } catch {
            destinationStates[id] = .failed(error)
            return
        }

        startEventForwarding(id: id, publisher: publisher)
    }

    /// Stop all destinations gracefully.
    public func stopAll() async {
        let activeIDs =
            destinationStates
            .filter { $0.value.isActive }
            .map(\.key)

        await withTaskGroup(of: Void.self) { group in
            for id in activeIDs {
                group.addTask { [self] in
                    try? await self.stop(id: id)
                }
            }
        }
    }

    /// Stop a specific destination by ID.
    ///
    /// - Parameter id: The destination ID to stop.
    /// - Throws: ``MultiPublisherError/destinationNotFound(_:)`` if the ID is not found.
    public func stop(id: String) async throws {
        guard var handle = handles[id] else {
            throw MultiPublisherError.destinationNotFound(id)
        }
        handle.eventTask?.cancel()
        handle.eventTask = nil
        handles[id] = handle
        await handle.publisher.disconnect()
        destinationStates[id] = .stopped
    }

    // MARK: - Media Sending

    /// Send an audio frame to all active destinations.
    ///
    /// Destinations not in ``DestinationState/streaming`` state silently skip this frame.
    ///
    /// - Parameters:
    ///   - data: The raw audio data.
    ///   - timestamp: The presentation timestamp.
    public func sendAudio(_ data: [UInt8], timestamp: UInt32) async {
        await withTaskGroup(of: Void.self) { group in
            for (id, handle) in handles {
                guard destinationStates[id] == .streaming else { continue }
                group.addTask {
                    try? await handle.publisher.sendAudio(data, timestamp: timestamp)
                }
            }
        }
        await updateAggregatedStatistics()
    }

    /// Send a video frame to all active destinations.
    ///
    /// Destinations not in ``DestinationState/streaming`` state silently skip this frame.
    ///
    /// - Parameters:
    ///   - data: The raw video data.
    ///   - timestamp: The presentation timestamp.
    ///   - isKeyframe: Whether this frame is a keyframe (I-frame).
    public func sendVideo(
        _ data: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for (id, handle) in handles {
                guard destinationStates[id] == .streaming else { continue }
                group.addTask {
                    try? await handle.publisher.sendVideo(
                        data, timestamp: timestamp, isKeyframe: isKeyframe
                    )
                }
            }
        }
        await updateAggregatedStatistics()
    }

    /// Send metadata to all active destinations.
    ///
    /// - Parameter metadata: The stream metadata to send.
    public func sendMetadata(_ metadata: StreamMetadata) async {
        await withTaskGroup(of: Void.self) { group in
            for (id, handle) in handles {
                guard destinationStates[id] == .streaming else { continue }
                group.addTask {
                    try? await handle.publisher.updateMetadata(metadata)
                }
            }
        }
    }

    // MARK: - Query

    /// Current state of a specific destination.
    ///
    /// - Parameter id: The destination ID.
    /// - Returns: The current state, or `nil` if the ID is not found.
    public func state(for id: String) -> DestinationState? {
        destinationStates[id]
    }

    /// Statistics for a specific destination.
    ///
    /// - Parameter id: The destination ID.
    /// - Returns: The connection statistics, or `nil` if the ID is not found.
    public func statistics(for id: String) async -> ConnectionStatistics? {
        guard let handle = handles[id] else { return nil }
        return await handle.publisher.statistics
    }

    // MARK: - Private Helpers

    private func startEventForwarding(
        id: String, publisher: RTMPPublisher
    ) {
        let events = publisher.events
        let continuation = eventContinuation
        let task = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled else { return }
                continuation.yield((id, event))
                await self?.handleDestinationEvent(id: id, event: event)
            }
        }
        handles[id]?.eventTask = task
    }

    private func handleDestinationEvent(
        id: String, event: RTMPEvent
    ) {
        switch event {
        case .stateChanged(let pubState):
            updateDestinationState(id: id, from: pubState)
        default:
            break
        }
    }

    private func updateDestinationState(
        id: String, from publisherState: RTMPPublisherState
    ) {
        switch publisherState {
        case .publishing:
            destinationStates[id] = .streaming
        case .connecting, .handshaking:
            destinationStates[id] = .connecting
        case .disconnected:
            destinationStates[id] = .stopped
        case .reconnecting(let attempt):
            destinationStates[id] = .reconnecting(attempt: attempt)
        case .failed(let error):
            destinationStates[id] = .failed(error)
        case .idle, .connected:
            break
        }
    }

    private func updateAggregatedStatistics() async {
        var perDest: [String: ConnectionStatistics] = [:]
        var totalBytes = 0
        var totalDropped = 0
        var active = 0
        var inactive = 0

        for (id, handle) in handles {
            let stats = await handle.publisher.statistics
            perDest[id] = stats
            totalBytes += Int(stats.bytesSent)
            totalDropped += Int(stats.droppedFrames)

            if destinationStates[id] == .streaming {
                active += 1
            }
        }

        for (_, state) in destinationStates {
            switch state {
            case .stopped, .failed:
                inactive += 1
            default:
                break
            }
        }

        statistics = MultiPublisherStatistics(
            perDestination: perDest,
            activeCount: active,
            inactiveCount: inactive,
            totalBytesSent: totalBytes,
            totalDroppedFrames: totalDropped,
            timestamp: Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
        )
    }
}
