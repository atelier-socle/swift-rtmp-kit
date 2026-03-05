// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Platform-specific streaming presets with recommended settings.
///
/// Each preset configures the optimal settings for the target platform:
/// chunk size, TLS requirements, Enhanced RTMP support, and more.
///
/// ## Supported Platforms
/// - ``twitch(_:)``: Twitch — RTMPS preferred, Enhanced RTMP beta
/// - ``youtube(ingestURL:)``: YouTube Live — RTMPS required
/// - ``facebook``: Facebook Live — RTMPS required
/// - ``kick``: Kick — RTMP/RTMPS supported
/// - ``instagram``: Instagram Live — RTMPS required
/// - ``tiktok``: TikTok Live — RTMPS required
/// - ``twitter``: X/Twitter Live — RTMPS via Periscope
/// - ``rumble``: Rumble — RTMP (no TLS)
/// - ``linkedin``: LinkedIn Live — RTMPS required
/// - ``trovo``: Trovo — RTMP (no TLS)
/// - ``custom``: Custom platform with default settings
public enum PlatformPreset: Sendable, Equatable {

    /// Twitch: RTMPS preferred, Enhanced RTMP beta.
    case twitch(TwitchIngestServer)

    /// YouTube Live: RTMPS required with SNI.
    case youtube(ingestURL: String)

    /// Facebook Live: RTMPS required.
    case facebook

    /// Kick: RTMP/RTMPS supported.
    case kick

    /// Instagram Live: RTMPS required.
    case instagram

    /// TikTok Live: RTMPS required.
    case tiktok

    /// X/Twitter Live: RTMPS via Periscope infrastructure.
    case twitter

    /// Rumble: standard RTMP (no TLS).
    case rumble

    /// LinkedIn Live: RTMPS required.
    case linkedin

    /// Trovo: standard RTMP (no TLS).
    case trovo

    /// Custom platform with default settings.
    case custom

    /// Human-readable platform name.
    public var name: String {
        switch self {
        case .twitch: "Twitch"
        case .youtube: "YouTube"
        case .facebook: "Facebook"
        case .kick: "Kick"
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .twitter: "Twitter"
        case .rumble: "Rumble"
        case .linkedin: "LinkedIn"
        case .trovo: "Trovo"
        case .custom: "Custom"
        }
    }

    /// The server URL for this preset (without stream key path).
    public var url: String {
        switch self {
        case .twitch(let server):
            return "rtmps://\(server.hostname)/app"
        case .youtube(let ingestURL):
            return ingestURL
        case .facebook:
            return "rtmps://live-api-s.facebook.com:443/rtmp"
        case .kick:
            return "rtmp://fa723fc1b171.global-contribute.live-video.net/app"
        case .instagram:
            return "rtmps://live-upload.instagram.com:443/rtmp/"
        case .tiktok:
            return "rtmps://push.tiktok.com/rtmp/"
        case .twitter:
            return "rtmps://prod-rtmp-publish.periscope.tv:443/"
        case .rumble:
            return "rtmp://publish.rumble.com/live/"
        case .linkedin:
            return "rtmps://livein.linkedin.com:443/live/"
        case .trovo:
            return "rtmp://livepush.trovo.live/live/"
        case .custom:
            return ""
        }
    }

    /// Default chunk size for the platform.
    public var chunkSize: UInt32 {
        4096
    }

    /// Whether RTMPS (TLS) is required by this platform.
    public var requiresTLS: Bool {
        switch self {
        case .twitch: false
        case .youtube: true
        case .facebook: true
        case .kick: false
        case .instagram: true
        case .tiktok: true
        case .twitter: true
        case .rumble: false
        case .linkedin: true
        case .trovo: false
        case .custom: false
        }
    }

    /// Whether Enhanced RTMP v2 is supported.
    public var supportsEnhancedRTMP: Bool {
        switch self {
        case .twitch: true
        case .youtube: true
        case .facebook, .kick, .instagram, .tiktok,
            .twitter, .rumble, .linkedin, .trovo, .custom:
            false
        }
    }

    /// Flash version string for the connect command.
    public var flashVersion: String {
        "FMLE/3.0 (compatible; FMSc/1.0)"
    }

    /// Maximum recommended bitrate in Kbps.
    public var maxBitrate: Int {
        switch self {
        case .twitch: 8500
        case .youtube: 9000
        case .facebook: 4000
        case .kick: 8000
        case .instagram: 3500
        case .tiktok: 4000
        case .twitter: 4000
        case .rumble: 8000
        case .linkedin: 5000
        case .trovo: 6000
        case .custom: 8000
        }
    }

    /// Recommended audio settings summary.
    public var audioRecommendation: String {
        switch self {
        case .twitch:
            return "AAC-LC, 128-320 Kbps, 48 kHz stereo"
        case .youtube:
            return "AAC-LC, 128-384 Kbps, 44.1/48 kHz stereo"
        case .facebook:
            return "AAC-LC, 128 Kbps, 44.1 kHz stereo"
        case .kick:
            return "AAC-LC, 128-320 Kbps, 48 kHz stereo"
        case .instagram:
            return "AAC-LC, 128 Kbps, 44.1 kHz stereo"
        case .tiktok:
            return "AAC-LC, 128 Kbps, 44.1/48 kHz stereo"
        case .twitter:
            return "AAC-LC, 128 Kbps, 44.1/48 kHz stereo"
        case .rumble:
            return "AAC-LC, 128-320 Kbps, 48 kHz stereo"
        case .linkedin:
            return "AAC-LC, 128 Kbps, 48 kHz stereo"
        case .trovo:
            return "AAC-LC, 128-256 Kbps, 48 kHz stereo"
        case .custom:
            return "AAC-LC, 128 Kbps, 48 kHz stereo"
        }
    }
}
