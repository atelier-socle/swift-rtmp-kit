// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// An immutable description of one publishing target within a ``MultiPublisher``.
///
/// Each destination has a unique identifier and an ``RTMPConfiguration``
/// that describes the server URL, stream key, and other settings.
public struct PublishDestination: Sendable {

    /// Unique identifier for this destination within a ``MultiPublisher``.
    public let id: String

    /// RTMP configuration for this destination (URL, stream key, presets, ABR, etc.).
    public let configuration: RTMPConfiguration

    /// Creates a destination with a full configuration.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this destination.
    ///   - configuration: The RTMP configuration to use.
    public init(id: String, configuration: RTMPConfiguration) {
        self.id = id
        self.configuration = configuration
    }
}

// MARK: - Convenience Initialisers

extension PublishDestination {

    /// Creates a destination with a URL and stream key.
    ///
    /// Uses default values for all other configuration options.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this destination.
    ///   - url: RTMP server URL.
    ///   - streamKey: The stream key.
    public init(id: String, url: String, streamKey: String) {
        self.id = id
        self.configuration = RTMPConfiguration(url: url, streamKey: streamKey)
    }
}
