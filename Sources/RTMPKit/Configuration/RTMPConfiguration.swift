// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Complete RTMP streaming configuration.
///
/// Bundles server URL, stream key, codec settings, transport options,
/// and reconnection policy into a single configuration object.
///
/// ## Usage
/// ```swift
/// // Simple
/// let config = RTMPConfiguration(
///     url: "rtmp://live.twitch.tv/app", streamKey: "live_xxx"
/// )
///
/// // Platform preset
/// let config = RTMPConfiguration.twitch(streamKey: "live_xxx")
///
/// // Fully customized
/// var config = RTMPConfiguration(
///     url: "rtmp://custom.server/app", streamKey: "key"
/// )
/// config.chunkSize = 8192
/// config.reconnectPolicy = .aggressive
/// config.enhancedRTMP = false
/// ```
public struct RTMPConfiguration: Sendable, Equatable {

    /// RTMP server URL (e.g., `"rtmp://live.twitch.tv/app"`).
    ///
    /// Should NOT include the stream key.
    public var url: String

    /// Stream key (kept separate from URL for security — not logged).
    public var streamKey: String

    /// RTMP chunk size to negotiate with the server (default: 4096).
    ///
    /// Common values: 4096, 8192, 16384.
    public var chunkSize: UInt32

    /// Whether to negotiate Enhanced RTMP v2 (default: `true`).
    ///
    /// When true, includes fourCcList in the connect command.
    public var enhancedRTMP: Bool

    /// Reconnection policy (default: ``ReconnectPolicy/default``).
    public var reconnectPolicy: ReconnectPolicy

    /// Platform preset that was used, if any.
    public var preset: PlatformPreset?

    /// Optional stream metadata to send after publish starts.
    public var metadata: StreamMetadata?

    /// Optional initial stream metadata sent automatically after publish starts.
    ///
    /// When set, this metadata is sent as an `@setDataFrame`/`onMetaData` message
    /// immediately after the publish command is acknowledged. Takes precedence
    /// over ``metadata`` for the initial send.
    public var initialMetadata: StreamMetadata?

    /// Flash version string for the connect command.
    ///
    /// Uses preset default if not overridden.
    public var flashVersion: String

    /// Transport-level configuration (timeouts, buffer sizes).
    public var transportConfiguration: TransportConfiguration

    /// Adaptive bitrate policy (default: ``AdaptiveBitratePolicy/disabled``).
    ///
    /// When set to a non-disabled policy, the publisher monitors network
    /// conditions and adjusts the video bitrate automatically.
    public var adaptiveBitrate: AdaptiveBitratePolicy

    /// AMF object encoding version (default: ``ObjectEncoding/amf0``).
    ///
    /// When set to `.amf3`, RTMP commands use type-17 messages and the
    /// connect command includes `objectEncoding: 3.0`.
    public var objectEncoding: ObjectEncoding

    /// Frame dropping strategy used when congestion is detected (default: ``FrameDroppingStrategy/default``).
    ///
    /// Controls which frames are dropped and in what order during
    /// network congestion to maintain stream stability.
    public var frameDroppingStrategy: FrameDroppingStrategy

    /// Create a configuration with a URL and stream key.
    ///
    /// - Parameters:
    ///   - url: The RTMP server URL (without stream key).
    ///   - streamKey: The stream key.
    ///   - chunkSize: RTMP chunk size (default: 4096).
    ///   - enhancedRTMP: Whether to negotiate Enhanced RTMP (default: true).
    ///   - reconnectPolicy: Reconnection strategy (default: `.default`).
    ///   - flashVersion: Flash version string for connect command.
    ///   - transportConfiguration: Transport-level settings.
    ///   - adaptiveBitrate: Adaptive bitrate policy (default: `.disabled`).
    ///   - frameDroppingStrategy: Frame dropping strategy (default: `.default`).
    public init(
        url: String,
        streamKey: String,
        chunkSize: UInt32 = 4096,
        enhancedRTMP: Bool = true,
        reconnectPolicy: ReconnectPolicy = .default,
        flashVersion: String = "FMLE/3.0 (compatible; FMSc/1.0)",
        transportConfiguration: TransportConfiguration = .default,
        adaptiveBitrate: AdaptiveBitratePolicy = .disabled,
        frameDroppingStrategy: FrameDroppingStrategy = .default
    ) {
        self.url = url
        self.streamKey = streamKey
        self.chunkSize = chunkSize
        self.enhancedRTMP = enhancedRTMP
        self.reconnectPolicy = reconnectPolicy
        self.preset = nil
        self.metadata = nil
        self.initialMetadata = nil
        self.flashVersion = flashVersion
        self.transportConfiguration = transportConfiguration
        self.objectEncoding = .amf0
        self.adaptiveBitrate = adaptiveBitrate
        self.frameDroppingStrategy = frameDroppingStrategy
    }

    // MARK: - Platform Convenience Factory Methods

    /// Create a Twitch configuration.
    ///
    /// - Parameters:
    ///   - streamKey: Your Twitch stream key.
    ///   - ingestServer: Ingest server (default: ``TwitchIngestServer/auto``).
    ///   - useTLS: Use RTMPS (default: `true`, recommended).
    /// - Returns: A configured ``RTMPConfiguration`` for Twitch.
    public static func twitch(
        streamKey: String,
        ingestServer: TwitchIngestServer = .auto,
        useTLS: Bool = true
    ) -> RTMPConfiguration {
        let scheme = useTLS ? "rtmps" : "rtmp"
        let url = "\(scheme)://\(ingestServer.hostname)/app"
        var config = RTMPConfiguration(url: url, streamKey: streamKey)
        config.enhancedRTMP = true
        config.preset = .twitch(ingestServer)
        return config
    }

    /// Create a YouTube Live configuration.
    ///
    /// - Parameters:
    ///   - streamKey: Your YouTube stream key.
    ///   - ingestURL: The RTMPS ingest URL from YouTube API.
    /// - Returns: A configured ``RTMPConfiguration`` for YouTube.
    public static func youtube(
        streamKey: String,
        ingestURL: String = "rtmps://a.rtmp.youtube.com/live2"
    ) -> RTMPConfiguration {
        var config = RTMPConfiguration(url: ingestURL, streamKey: streamKey)
        config.enhancedRTMP = true
        config.preset = .youtube(ingestURL: ingestURL)
        return config
    }

    /// Create a Facebook Live configuration.
    ///
    /// - Parameters:
    ///   - streamKey: Your Facebook stream key.
    /// - Returns: A configured ``RTMPConfiguration`` for Facebook.
    public static func facebook(
        streamKey: String
    ) -> RTMPConfiguration {
        var config = RTMPConfiguration(
            url: "rtmps://live-api-s.facebook.com:443/rtmp",
            streamKey: streamKey
        )
        config.enhancedRTMP = false
        config.preset = .facebook
        return config
    }

    /// Create a Kick configuration.
    ///
    /// - Parameters:
    ///   - streamKey: Your Kick stream key.
    ///   - ingestURL: Kick ingest URL (obtained from dashboard).
    /// - Returns: A configured ``RTMPConfiguration`` for Kick.
    public static func kick(
        streamKey: String,
        ingestURL: String = "rtmp://fa723fc1b171.global-contribute.live-video.net/app"
    ) -> RTMPConfiguration {
        var config = RTMPConfiguration(url: ingestURL, streamKey: streamKey)
        config.enhancedRTMP = false
        config.preset = .kick
        return config
    }
}
