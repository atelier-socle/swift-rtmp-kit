// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Re-publishes an ingest stream to one or more RTMP destinations.
///
/// Attach to an ``RTMPServer`` via ``RTMPServer/attachRelay(_:toStream:)``
/// to relay frames as they arrive from a publisher session.
///
/// ## Usage
/// ```swift
/// let relay = RTMPStreamRelay(destinations: [
///     .init(id: "twitch", configuration: .twitch(streamKey: "live_xxx")),
///     .init(id: "youtube", configuration: .youtube(streamKey: "yyyy"))
/// ])
/// try await relay.start()
/// await relay.relayVideo(videoBytes, timestamp: 0, isKeyframe: true)
/// await relay.stop()
/// ```
public actor RTMPStreamRelay {

    // MARK: - Configuration

    /// A single relay destination.
    public struct RelayDestination: Sendable {
        /// Unique identifier for this destination.
        public let id: String
        /// RTMP configuration for connecting to this destination.
        public let configuration: RTMPConfiguration

        /// Creates a new relay destination.
        ///
        /// - Parameters:
        ///   - id: Unique identifier.
        ///   - configuration: RTMP connection configuration.
        public init(id: String, configuration: RTMPConfiguration) {
            self.id = id
            self.configuration = configuration
        }
    }

    // MARK: - State

    /// Relay lifecycle states.
    public enum State: Sendable, Equatable {
        /// Relay has not been started.
        case idle
        /// Relay is actively forwarding frames.
        case relaying
        /// Relay has been stopped.
        case stopped
    }

    /// Current relay state.
    public private(set) var state: State

    // MARK: - Statistics

    /// Total frames relayed successfully across all destinations.
    public private(set) var framesRelayed: Int

    /// Number of destinations currently in active state.
    public var activeDestinationCount: Int {
        get async {
            let states = await multiPublisher.destinationStates
            return states.values.filter(\.isActive).count
        }
    }

    // MARK: - Private

    private let multiPublisher: MultiPublisher
    private let destinations: [RelayDestination]

    // MARK: - Init

    /// Creates a new stream relay with the given destinations.
    ///
    /// Uses the default NIO transport for each destination.
    ///
    /// - Parameter destinations: The RTMP destinations to relay to.
    public init(destinations: [RelayDestination]) {
        self.destinations = destinations
        self.multiPublisher = MultiPublisher()
        self.state = .idle
        self.framesRelayed = 0
    }

    /// Creates a new stream relay with a custom transport factory.
    ///
    /// Use this in tests to inject ``MockTransport`` per destination.
    ///
    /// - Parameters:
    ///   - destinations: The RTMP destinations to relay to.
    ///   - transportFactory: Factory that creates a transport for each
    ///     destination configuration.
    internal init(
        destinations: [RelayDestination],
        transportFactory: @escaping @Sendable (RTMPConfiguration) -> any RTMPTransportProtocol
    ) {
        self.destinations = destinations
        self.multiPublisher = MultiPublisher(
            transportFactory: transportFactory
        )
        self.state = .idle
        self.framesRelayed = 0
    }

    // MARK: - Lifecycle

    /// Start relaying. Connects all destination publishers.
    public func start() async throws {
        guard state == .idle else { return }
        for dest in destinations {
            try await multiPublisher.addDestination(
                PublishDestination(
                    id: dest.id,
                    configuration: dest.configuration
                )
            )
        }
        await multiPublisher.startAll()
        state = .relaying
    }

    /// Stop relaying. Disconnects all destination publishers.
    public func stop() async {
        guard state == .relaying else { return }
        await multiPublisher.stopAll()
        state = .stopped
    }

    // MARK: - Frame Ingestion

    /// Forward a video frame to all relay destinations.
    ///
    /// - Parameters:
    ///   - data: Raw video frame data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    ///   - isKeyframe: Whether this is a keyframe (I-frame).
    public func relayVideo(
        _ data: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) async {
        guard state == .relaying else { return }
        await multiPublisher.sendVideo(
            data, timestamp: timestamp, isKeyframe: isKeyframe
        )
        framesRelayed += 1
    }

    /// Forward an audio frame to all relay destinations.
    ///
    /// - Parameters:
    ///   - data: Raw audio frame data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    public func relayAudio(
        _ data: [UInt8], timestamp: UInt32
    ) async {
        guard state == .relaying else { return }
        await multiPublisher.sendAudio(data, timestamp: timestamp)
        framesRelayed += 1
    }

    /// Forward metadata to all relay destinations.
    ///
    /// - Parameter metadata: The stream metadata to relay.
    public func relayMetadata(_ metadata: StreamMetadata) async {
        guard state == .relaying else { return }
        await multiPublisher.sendMetadata(metadata)
    }
}
