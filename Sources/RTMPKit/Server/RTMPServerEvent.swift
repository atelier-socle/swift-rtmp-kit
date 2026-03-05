// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Events emitted by ``RTMPServer``.
///
/// Consumers observe server lifecycle, session connections, and stream activity.
public enum RTMPServerEvent: Sendable {
    /// Server started and is listening on the given port.
    case started(port: Int)
    /// Server stopped.
    case stopped
    /// A new publisher connected and completed the handshake.
    case sessionConnected(RTMPServerSession)
    /// A publisher started streaming with the given stream name.
    case streamStarted(session: RTMPServerSession, streamName: String)
    /// A publisher stopped streaming.
    case streamStopped(session: RTMPServerSession, streamName: String)
    /// A session disconnected.
    case sessionDisconnected(id: UUID, reason: String)
    /// A video frame was received from a publisher.
    case videoFrame(sessionID: UUID, data: [UInt8], timestamp: UInt32, isKeyframe: Bool)
    /// An audio frame was received from a publisher.
    case audioFrame(sessionID: UUID, data: [UInt8], timestamp: UInt32)
    /// A non-fatal error occurred (server continues running).
    case error(String)
}
