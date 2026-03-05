// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import RTMPKit

/// Parses a `--dest` argument into an ``RTMPConfiguration``.
///
/// Supported formats:
/// - `twitch:<streamKey>` → ``RTMPConfiguration/twitch(streamKey:)``
/// - `youtube:<streamKey>` → ``RTMPConfiguration/youtube(streamKey:)``
/// - `facebook:<streamKey>` → ``RTMPConfiguration/facebook(streamKey:)``
/// - `kick:<streamKey>` → ``RTMPConfiguration/kick(streamKey:)``
/// - `rtmp://server/app:<streamKey>` → custom URL
/// - `rtmps://server/app:<streamKey>` → custom RTMPS URL
public struct DestinationArgument: Sendable {

    /// The parsed configuration.
    public let configuration: RTMPConfiguration

    /// The destination ID derived from the argument.
    public let id: String
}

extension DestinationArgument: ExpressibleByArgument {

    /// Parses a destination argument string.
    ///
    /// - Parameter argument: The raw argument string in `platform:key` or `url:key` format.
    public init?(argument: String) {
        if argument.hasPrefix("rtmp://") || argument.hasPrefix("rtmps://") {
            guard let parsed = Self.parseURL(argument) else { return nil }
            self = parsed
        } else {
            guard let parsed = Self.parsePlatform(argument) else { return nil }
            self = parsed
        }
    }
}

// MARK: - Private Parsing

extension DestinationArgument {

    /// Parse a raw RTMP/RTMPS URL argument.
    private static func parseURL(_ argument: String) -> DestinationArgument? {
        guard let lastColon = argument.lastIndex(of: ":") else { return nil }
        let colonOffset = argument.distance(
            from: argument.startIndex, to: lastColon
        )
        // Must not be the scheme colon (position 4 for rtmp, 5 for rtmps)
        guard colonOffset > 7 else { return nil }
        let url = String(argument[argument.startIndex..<lastColon])
        let streamKey = String(argument[argument.index(after: lastColon)...])
        guard !streamKey.isEmpty else { return nil }
        return DestinationArgument(
            configuration: RTMPConfiguration(url: url, streamKey: streamKey),
            id: url
        )
    }

    /// Parse a platform shortcut argument (e.g., `twitch:key`).
    private static func parsePlatform(_ argument: String) -> DestinationArgument? {
        guard let colonIndex = argument.firstIndex(of: ":") else { return nil }
        let platform = String(argument[argument.startIndex..<colonIndex]).lowercased()
        let streamKey = String(argument[argument.index(after: colonIndex)...])
        guard !streamKey.isEmpty else { return nil }

        guard let config = platformConfiguration(platform, streamKey: streamKey) else {
            return nil
        }
        return DestinationArgument(configuration: config, id: platform)
    }

    /// Map a platform name to an ``RTMPConfiguration``.
    private static func platformConfiguration(
        _ platform: String, streamKey: String
    ) -> RTMPConfiguration? {
        switch platform {
        case "twitch": return .twitch(streamKey: streamKey)
        case "youtube": return .youtube(streamKey: streamKey)
        case "facebook": return .facebook(streamKey: streamKey)
        case "kick": return .kick(streamKey: streamKey)
        default: return nil
        }
    }
}
