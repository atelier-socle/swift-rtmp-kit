// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A registry of all streaming platforms supported by RTMPKit.
///
/// Provides discovery, metadata, and configuration helpers for
/// all supported streaming platforms.
///
/// ## Usage
/// ```swift
/// // List all platforms
/// for platform in StreamingPlatformRegistry.allPlatforms {
///     print("\(platform.name): TLS=\(platform.requiresTLS)")
/// }
///
/// // Look up by name
/// if let preset = StreamingPlatformRegistry.platform(named: "twitch") {
///     print(preset.maxBitrate)
/// }
///
/// // Build a config from a name
/// let config = StreamingPlatformRegistry.configuration(
///     platform: "youtube", streamKey: "my-key"
/// )
/// ```
public struct StreamingPlatformRegistry: Sendable {

    /// All platforms supported by RTMPKit, in alphabetical order.
    ///
    /// Does not include ``PlatformPreset/custom``.
    public static var allPlatforms: [PlatformPreset] {
        [
            .facebook,
            .instagram,
            .kick,
            .linkedin,
            .rumble,
            .tiktok,
            .trovo,
            .twitch(.auto),
            .twitter,
            .youtube(ingestURL: "rtmps://a.rtmp.youtube.com/live2")
        ]
    }

    /// All platforms that require TLS (RTMPS).
    public static var tlsRequiredPlatforms: [PlatformPreset] {
        allPlatforms.filter(\.requiresTLS)
    }

    /// All platforms that support Enhanced RTMP v2.
    public static var enhancedRTMPPlatforms: [PlatformPreset] {
        allPlatforms.filter(\.supportsEnhancedRTMP)
    }

    /// Returns a platform preset by its string name (case-insensitive).
    ///
    /// - Parameter name: The platform name (e.g. `"twitch"`, `"YouTube"`).
    /// - Returns: The matching ``PlatformPreset``, or `nil` if not recognized.
    public static func platform(named name: String) -> PlatformPreset? {
        presetsByName[name.lowercased()]
    }

    /// Build an ``RTMPConfiguration`` for the named platform and stream key.
    ///
    /// - Parameters:
    ///   - platform: The platform name (case-insensitive).
    ///   - streamKey: The stream key.
    /// - Returns: A configured ``RTMPConfiguration``, or `nil` if the platform is not recognized.
    public static func configuration(
        platform: String,
        streamKey: String
    ) -> RTMPConfiguration? {
        configFactoriesByName[platform.lowercased()]?(streamKey)
    }

    // MARK: - Private

    private static let presetsByName: [String: PlatformPreset] = [
        "facebook": .facebook,
        "instagram": .instagram,
        "kick": .kick,
        "linkedin": .linkedin,
        "rumble": .rumble,
        "tiktok": .tiktok,
        "trovo": .trovo,
        "twitch": .twitch(.auto),
        "twitter": .twitter,
        "x": .twitter,
        "youtube": .youtube(ingestURL: "rtmps://a.rtmp.youtube.com/live2")
    ]

    private static let configFactoriesByName: [String: @Sendable (String) -> RTMPConfiguration] = [
        "facebook": { RTMPConfiguration.facebook(streamKey: $0) },
        "instagram": { RTMPConfiguration.instagram(streamKey: $0) },
        "kick": { RTMPConfiguration.kick(streamKey: $0) },
        "linkedin": { RTMPConfiguration.linkedin(streamKey: $0) },
        "rumble": { RTMPConfiguration.rumble(streamKey: $0) },
        "tiktok": { RTMPConfiguration.tiktok(streamKey: $0) },
        "trovo": { RTMPConfiguration.trovo(streamKey: $0) },
        "twitch": { RTMPConfiguration.twitch(streamKey: $0) },
        "twitter": { RTMPConfiguration.twitter(streamKey: $0) },
        "x": { RTMPConfiguration.twitter(streamKey: $0) },
        "youtube": { RTMPConfiguration.youtube(streamKey: $0) }
    ]

    /// Private initializer prevents instantiation.
    private init() {}
}
