// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Known RTMP status codes from server onStatus responses.
///
/// These codes appear in the `"code"` field of onStatus command info objects.
/// Used to interpret server responses during the publish lifecycle.
///
/// ## Usage
/// ```swift
/// if let code = RTMPStatusCode(rawValue: "NetStream.Publish.Start") {
///     print(code.isSuccess) // true
///     print(code.category)  // .publish
/// }
/// ```
public enum RTMPStatusCode: String, Sendable, CaseIterable, Equatable {

    // MARK: - Publish

    /// Stream publish started successfully.
    case publishStart = "NetStream.Publish.Start"

    /// Stream name is already in use or invalid.
    case publishBadName = "NetStream.Publish.BadName"

    /// Stream is idle (no data being published).
    case publishIdle = "NetStream.Publish.Idle"

    /// Publish request was rejected by the server.
    case publishRejected = "NetStream.Publish.Rejected"

    // MARK: - Unpublish

    /// Stream was unpublished successfully.
    case unpublishSuccess = "NetStream.Unpublish.Success"

    // MARK: - Connection

    /// Connection to the server succeeded.
    case connectSuccess = "NetConnection.Connect.Success"

    /// Connection was rejected by the server.
    case connectRejected = "NetConnection.Connect.Rejected"

    /// Connection was closed by the server.
    case connectClosed = "NetConnection.Connect.Closed"

    /// Connection attempt failed.
    case connectFailed = "NetConnection.Connect.Failed"

    // MARK: - Stream

    /// Stream playback was reset.
    case streamReset = "NetStream.Play.Reset"

    /// A stream-level error occurred.
    case streamFailed = "NetStream.Failed"

    /// Whether this status indicates success.
    public var isSuccess: Bool {
        switch self {
        case .publishStart, .connectSuccess, .unpublishSuccess:
            true
        default:
            false
        }
    }

    /// Whether this status indicates an error.
    public var isError: Bool {
        switch self {
        case .publishBadName, .publishRejected, .connectRejected,
            .connectFailed, .connectClosed, .streamFailed:
            true
        default:
            false
        }
    }

    /// The category of this status.
    public var category: StatusCategory {
        switch self {
        case .connectSuccess, .connectRejected, .connectClosed,
            .connectFailed:
            .connection
        case .publishStart, .publishBadName, .publishIdle,
            .publishRejected, .unpublishSuccess:
            .publish
        case .streamReset, .streamFailed:
            .stream
        }
    }

    /// Status categories.
    public enum StatusCategory: Sendable, Equatable {
        /// Connection-level status.
        case connection
        /// Publish-level status.
        case publish
        /// Stream-level status.
        case stream
    }
}
