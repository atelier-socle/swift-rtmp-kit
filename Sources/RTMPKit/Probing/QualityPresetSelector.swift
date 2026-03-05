// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Selects the optimal quality preset for a given platform based on probe results.
///
/// Uses a standard quality ladder to pick the highest quality that fits
/// within the available bandwidth, then configures the ``RTMPConfiguration``
/// with appropriate metadata and adaptive bitrate settings.
///
/// ## Usage
/// ```swift
/// let result = try await probe.probe(url: "rtmp://server/app")
/// let config = QualityPresetSelector.select(
///     for: result, platform: .twitch(.auto), streamKey: "live_key"
/// )
/// ```
public struct QualityPresetSelector: Sendable {

    /// Private initializer prevents instantiation.
    private init() {}

    /// Selects the highest-quality ``RTMPConfiguration`` that fits within
    /// the probe result's ``ProbeResult/recommendedBitrate``.
    ///
    /// The returned configuration has ``RTMPConfiguration/initialMetadata``
    /// set with appropriate video/audio bitrate and resolution, and ABR
    /// enabled with a ``AdaptiveBitratePolicy/responsive(min:max:)`` policy.
    ///
    /// - Parameters:
    ///   - result: The bandwidth probe result.
    ///   - platform: The target platform preset.
    ///   - streamKey: The stream key.
    /// - Returns: The optimal configuration.
    public static func select(
        for result: ProbeResult,
        platform: PlatformPreset,
        streamKey: String
    ) -> RTMPConfiguration {
        let tier = selectTier(
            for: result.recommendedBitrate,
            platformMax: platform.maxBitrate * 1000
        )

        var config = buildConfig(platform: platform, streamKey: streamKey)
        config.initialMetadata = tier.metadata
        config.adaptiveBitrate = .responsive(
            min: tier.minBitrate, max: tier.totalBitrate
        )
        return config
    }

    /// Selects from a list of candidate configurations sorted descending
    /// by their ``StreamMetadata/videoBitrate``, returning the highest one
    /// that fits within `availableBandwidth`.
    ///
    /// - Parameters:
    ///   - candidates: Configurations sorted highest bitrate first.
    ///   - availableBandwidth: Maximum usable bandwidth in bps.
    /// - Returns: The best fitting configuration, or the lowest candidate.
    public static func select(
        from candidates: [RTMPConfiguration],
        availableBandwidth: Int
    ) -> RTMPConfiguration {
        guard !candidates.isEmpty else {
            return fallbackConfig()
        }

        for candidate in candidates {
            let bitrate = candidateBitrate(candidate)
            if bitrate <= availableBandwidth {
                return candidate
            }
        }

        // None fit — return the lowest (last) candidate
        return candidates[candidates.count - 1]
    }
}

// MARK: - Quality Ladder

extension QualityPresetSelector {

    /// A quality tier in the standard quality ladder.
    public struct QualityTier: Sendable, Equatable {
        /// Tier display name (e.g. "1080p60").
        public let name: String
        /// Video bitrate in bps.
        public let videoBitrate: Int
        /// Audio bitrate in bps.
        public let audioBitrate: Int
        /// Frame width.
        public let width: Int
        /// Frame height.
        public let height: Int
        /// Frames per second.
        public let frameRate: Double

        /// Total bitrate (video + audio) in bps.
        public var totalBitrate: Int { videoBitrate + audioBitrate }

        /// Minimum ABR bitrate — one tier below.
        var minBitrate: Int { totalBitrate / 2 }

        /// Stream metadata for this tier.
        var metadata: StreamMetadata {
            .h264AAC(
                width: width, height: height,
                frameRate: frameRate,
                videoBitrate: videoBitrate,
                audioBitrate: audioBitrate
            )
        }
    }

    /// The standard quality ladder, sorted highest to lowest.
    public static let qualityLadder: [QualityTier] = [
        QualityTier(
            name: "1080p60",
            videoBitrate: 8_000_000, audioBitrate: 320_000,
            width: 1920, height: 1080, frameRate: 60
        ),
        QualityTier(
            name: "1080p30",
            videoBitrate: 6_000_000, audioBitrate: 192_000,
            width: 1920, height: 1080, frameRate: 30
        ),
        QualityTier(
            name: "720p60",
            videoBitrate: 4_000_000, audioBitrate: 160_000,
            width: 1280, height: 720, frameRate: 60
        ),
        QualityTier(
            name: "720p30",
            videoBitrate: 2_500_000, audioBitrate: 128_000,
            width: 1280, height: 720, frameRate: 30
        ),
        QualityTier(
            name: "480p30",
            videoBitrate: 1_500_000, audioBitrate: 96_000,
            width: 854, height: 480, frameRate: 30
        ),
        QualityTier(
            name: "360p30",
            videoBitrate: 800_000, audioBitrate: 64_000,
            width: 640, height: 360, frameRate: 30
        )
    ]

    // MARK: - Private

    private static func selectTier(
        for bandwidth: Int, platformMax: Int
    ) -> QualityTier {
        let effectiveBandwidth = min(bandwidth, platformMax)
        for tier in qualityLadder where tier.totalBitrate <= effectiveBandwidth {
            return tier
        }
        return qualityLadder[qualityLadder.count - 1]
    }

    private static func buildConfig(
        platform: PlatformPreset, streamKey: String
    ) -> RTMPConfiguration {
        StreamingPlatformRegistry.configuration(
            platform: platform.name, streamKey: streamKey
        ) ?? RTMPConfiguration(url: platform.url, streamKey: streamKey)
    }

    private static func candidateBitrate(
        _ config: RTMPConfiguration
    ) -> Int {
        let video =
            config.initialMetadata?.videoBitrate
            ?? config.metadata?.videoBitrate ?? 0
        let audio =
            config.initialMetadata?.audioBitrate
            ?? config.metadata?.audioBitrate ?? 0
        return video + audio
    }

    private static func fallbackConfig() -> RTMPConfiguration {
        let lowest = qualityLadder[qualityLadder.count - 1]
        var config = RTMPConfiguration(
            url: "", streamKey: ""
        )
        config.initialMetadata = lowest.metadata
        return config
    }
}
