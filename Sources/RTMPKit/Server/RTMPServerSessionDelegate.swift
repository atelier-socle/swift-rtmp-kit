// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Delegate protocol for RTMPServer session events.
///
/// All methods have default no-op implementations so conforming types
/// only need to implement the methods they care about.
public protocol RTMPServerSessionDelegate: AnyObject, Sendable {

    /// Called when a new publisher session connects and completes the handshake.
    ///
    /// - Parameter session: The newly connected session.
    func serverSessionDidConnect(_ session: RTMPServerSession) async

    /// Called when a publisher starts streaming.
    ///
    /// Return `false` to reject the stream (server sends `NetStream.Publish.BadName`).
    ///
    /// - Parameters:
    ///   - session: The session requesting to publish.
    ///   - streamName: The stream key/name being published.
    /// - Returns: `true` to accept, `false` to reject.
    func serverSession(
        _ session: RTMPServerSession,
        shouldAcceptStream streamName: String
    ) async -> Bool

    /// Called when a video frame is received from a publisher.
    ///
    /// - Parameters:
    ///   - session: The publishing session.
    ///   - data: Raw video frame bytes.
    ///   - timestamp: Frame timestamp in milliseconds.
    ///   - isKeyframe: Whether this frame is a keyframe.
    func serverSession(
        _ session: RTMPServerSession,
        didReceiveVideo data: [UInt8],
        timestamp: UInt32,
        isKeyframe: Bool
    ) async

    /// Called when an audio frame is received from a publisher.
    ///
    /// - Parameters:
    ///   - session: The publishing session.
    ///   - data: Raw audio frame bytes.
    ///   - timestamp: Frame timestamp in milliseconds.
    func serverSession(
        _ session: RTMPServerSession,
        didReceiveAudio data: [UInt8],
        timestamp: UInt32
    ) async

    /// Called when a publisher sends stream metadata.
    ///
    /// - Parameters:
    ///   - session: The publishing session.
    ///   - metadata: The stream metadata.
    func serverSession(
        _ session: RTMPServerSession,
        didReceiveMetadata metadata: StreamMetadata
    ) async

    /// Called when a session disconnects (cleanly or due to error).
    ///
    /// - Parameters:
    ///   - session: The disconnected session.
    ///   - reason: Human-readable disconnect reason.
    func serverSessionDidDisconnect(
        _ session: RTMPServerSession,
        reason: String
    ) async
}

/// Default no-op implementations.
extension RTMPServerSessionDelegate {

    /// Default: no action on connect.
    public func serverSessionDidConnect(_ session: RTMPServerSession) async {}

    /// Default: accept all streams.
    public func serverSession(
        _ session: RTMPServerSession,
        shouldAcceptStream streamName: String
    ) async -> Bool { true }

    /// Default: no action on video.
    public func serverSession(
        _ session: RTMPServerSession,
        didReceiveVideo data: [UInt8],
        timestamp: UInt32,
        isKeyframe: Bool
    ) async {}

    /// Default: no action on audio.
    public func serverSession(
        _ session: RTMPServerSession,
        didReceiveAudio data: [UInt8],
        timestamp: UInt32
    ) async {}

    /// Default: no action on metadata.
    public func serverSession(
        _ session: RTMPServerSession,
        didReceiveMetadata metadata: StreamMetadata
    ) async {}

    /// Default: no action on disconnect.
    public func serverSessionDidDisconnect(
        _ session: RTMPServerSession,
        reason: String
    ) async {}
}
