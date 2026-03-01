// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Parsed status information from an RTMP `onStatus` info object.
///
/// Extracts the `code`, `level`, and `description` fields from the
/// AMF0 object sent by the server.
public struct StatusInfo: Sendable, Equatable {

    /// Status code (e.g., `"NetStream.Publish.Start"`).
    public var code: String

    /// Status level (e.g., `"status"` or `"error"`).
    public var level: String

    /// Human-readable description from the server.
    public var description: String

    /// Creates a status info with default unknown values.
    public init(
        code: String = "unknown",
        level: String = "",
        description: String = ""
    ) {
        self.code = code
        self.level = level
        self.description = description
    }
}
