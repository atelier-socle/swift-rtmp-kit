// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Configuration Showcase")
struct ConfigurationShowcaseTests {

    // MARK: - Platform Presets

    @Test("Twitch configuration with default ingest")
    func twitchDefaultIngest() {
        let config = RTMPConfiguration.twitch(
            streamKey: "live_abc123"
        )

        // URL uses RTMPS and auto ingest (live.twitch.tv)
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.url.contains("twitch.tv"))
        #expect(config.streamKey == "live_abc123")

        // Enhanced RTMP is enabled for Twitch
        #expect(config.enhancedRTMP == true)

        // Default chunk size is 4096
        #expect(config.chunkSize == 4096)

        // Default reconnect policy
        #expect(config.reconnectPolicy == .default)

        // Preset is stored
        #expect(
            config.preset
                == .twitch(.auto)
        )
    }

    @Test("Twitch configuration with specific ingest server")
    func twitchSpecificIngest() {
        let config = RTMPConfiguration.twitch(
            streamKey: "live_eu_key",
            ingestServer: .europe
        )

        // URL contains the Europe ingest hostname
        #expect(config.url.contains("ams03"))
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(
            config.preset == .twitch(.europe)
        )
    }

    @Test("All Twitch ingest servers produce valid URLs")
    func allTwitchIngestServers() {
        for server in TwitchIngestServer.allCases {
            let config = RTMPConfiguration.twitch(
                streamKey: "key",
                ingestServer: server
            )
            #expect(!config.url.isEmpty)
            #expect(config.url.hasPrefix("rtmps://"))
            #expect(!server.hostname.isEmpty)
        }
    }

    @Test("YouTube configuration requires RTMPS")
    func youtubeConfig() {
        let config = RTMPConfiguration.youtube(
            streamKey: "xxxx-xxxx-xxxx-xxxx"
        )

        #expect(config.streamKey == "xxxx-xxxx-xxxx-xxxx")
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.url.contains("youtube.com"))
        #expect(config.enhancedRTMP == true)

        // Preset stores the ingest URL
        if case .youtube(let ingestURL) = config.preset {
            #expect(ingestURL.contains("youtube.com"))
        } else {
            Issue.record("Expected .youtube preset")
        }

        // YouTube requires TLS
        #expect(config.preset?.requiresTLS == true)
    }

    @Test(
        "YouTube configuration with custom ingest URL"
    )
    func youtubeCustomIngest() {
        let customURL =
            "rtmps://custom.youtube.com/live2"
        let config = RTMPConfiguration.youtube(
            streamKey: "yt-key",
            ingestURL: customURL
        )

        // Custom URL is used instead of default
        #expect(config.url == customURL)
    }

    @Test("Facebook configuration")
    func facebookConfig() {
        let config = RTMPConfiguration.facebook(
            streamKey: "FB-xxxx"
        )

        #expect(config.streamKey == "FB-xxxx")
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.url.contains("facebook.com"))

        // Facebook does NOT support Enhanced RTMP
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .facebook)
        #expect(config.preset?.requiresTLS == true)
    }

    @Test("Kick configuration")
    func kickConfig() {
        let config = RTMPConfiguration.kick(
            streamKey: "kick_key_123"
        )

        #expect(config.streamKey == "kick_key_123")
        #expect(!config.url.isEmpty)
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .kick)

        // Kick does not require TLS
        #expect(config.preset?.requiresTLS == false)
    }

    // MARK: - Custom Configuration

    @Test("Custom configuration with all parameters")
    func customFullConfig() {
        let config = RTMPConfiguration(
            url: "rtmp://custom.server.com/app",
            streamKey: "mykey",
            chunkSize: 8192,
            enhancedRTMP: true,
            reconnectPolicy: .aggressive,
            flashVersion: "CustomEncoder/1.0",
            transportConfiguration: .lowLatency
        )

        #expect(config.url == "rtmp://custom.server.com/app")
        #expect(config.streamKey == "mykey")
        #expect(config.chunkSize == 8192)
        #expect(config.enhancedRTMP == true)
        #expect(config.reconnectPolicy == .aggressive)
        #expect(config.flashVersion == "CustomEncoder/1.0")
        #expect(
            config.transportConfiguration
                == .lowLatency
        )

        // No preset for custom configs
        #expect(config.preset == nil)
        // Metadata is nil by default
        #expect(config.metadata == nil)
    }

    @Test("Default configuration values")
    func defaultConfigValues() {
        let config = RTMPConfiguration(
            url: "rtmp://server/app",
            streamKey: "key"
        )

        #expect(config.chunkSize == 4096)
        #expect(config.enhancedRTMP == true)
        #expect(config.reconnectPolicy == .default)
        #expect(
            config.flashVersion
                == "FMLE/3.0 (compatible; FMSc/1.0)"
        )
        #expect(
            config.transportConfiguration == .default
        )
    }

    // MARK: - PlatformPreset Properties

    @Test("PlatformPreset exposes all properties")
    func presetProperties() {
        // All 5 presets accessible
        let presets: [PlatformPreset] = [
            .twitch(.auto),
            .youtube(ingestURL: "rtmps://yt"),
            .facebook,
            .kick,
            .custom
        ]

        for preset in presets {
            // Every preset has a URL, chunkSize, flashVersion
            _ = preset.url
            #expect(preset.chunkSize == 4096)
            #expect(!preset.flashVersion.isEmpty)
            #expect(preset.maxBitrate > 0)
            #expect(!preset.audioRecommendation.isEmpty)
        }

        // Enhanced RTMP support
        #expect(
            PlatformPreset.twitch(.auto)
                .supportsEnhancedRTMP
        )
        #expect(
            PlatformPreset.youtube(ingestURL: "")
                .supportsEnhancedRTMP
        )
        #expect(!PlatformPreset.facebook.supportsEnhancedRTMP)
        #expect(!PlatformPreset.kick.supportsEnhancedRTMP)
        #expect(!PlatformPreset.custom.supportsEnhancedRTMP)

        // Custom preset URL is empty
        #expect(PlatformPreset.custom.url.isEmpty)
    }

    // MARK: - Reconnect Policies

    @Test("Default reconnect policy parameters")
    func defaultReconnectPolicy() {
        let policy = ReconnectPolicy.default
        #expect(policy.maxAttempts == 5)
        #expect(policy.initialDelay == 1.0)
        #expect(policy.maxDelay == 30.0)
        #expect(policy.multiplier == 2.0)
        #expect(policy.jitter == 0.1)
        #expect(policy.isEnabled)
    }

    @Test("Aggressive reconnect policy parameters")
    func aggressiveReconnectPolicy() {
        let policy = ReconnectPolicy.aggressive
        #expect(policy.maxAttempts == 10)
        #expect(policy.initialDelay == 0.5)
        #expect(policy.maxDelay == 15.0)
        #expect(policy.multiplier == 1.5)
        #expect(policy.isEnabled)
    }

    @Test("Conservative reconnect policy parameters")
    func conservativeReconnectPolicy() {
        let policy = ReconnectPolicy.conservative
        #expect(policy.maxAttempts == 3)
        #expect(policy.initialDelay == 2.0)
        #expect(policy.maxDelay == 60.0)
        #expect(policy.multiplier == 3.0)
        #expect(policy.isEnabled)
    }

    @Test("None reconnect policy: no retries")
    func noneReconnectPolicy() {
        let policy = ReconnectPolicy.none
        #expect(policy.maxAttempts == 0)
        #expect(!policy.isEnabled)

        // Attempt 0 is already exhausted
        #expect(policy.delay(forAttempt: 0) == nil)
        #expect(policy.baseDelay(forAttempt: 0) == nil)
    }

    @Test("Exponential backoff with deterministic base delay")
    func exponentialBackoff() {
        let policy = ReconnectPolicy.default

        // baseDelay is deterministic (no jitter)
        #expect(policy.baseDelay(forAttempt: 0) == 1.0)
        #expect(policy.baseDelay(forAttempt: 1) == 2.0)
        #expect(policy.baseDelay(forAttempt: 2) == 4.0)
        #expect(policy.baseDelay(forAttempt: 3) == 8.0)
        #expect(policy.baseDelay(forAttempt: 4) == 16.0)

        // Attempt 5 exceeds maxAttempts(5) → nil
        #expect(policy.baseDelay(forAttempt: 5) == nil)

        // Negative attempt → nil
        #expect(policy.baseDelay(forAttempt: -1) == nil)

        // delay() includes jitter but stays within bounds
        if let d = policy.delay(forAttempt: 0) {
            // 1.0 ± 10% → [0.9, 1.1]
            #expect(d >= 0.9)
            #expect(d <= 1.1)
        }
    }

    @Test("Custom reconnect policy with capping")
    func customReconnectPolicy() {
        let policy = ReconnectPolicy(
            maxAttempts: 2,
            initialDelay: 0.1,
            maxDelay: 1.0,
            multiplier: 10,
            jitter: 0
        )

        // Attempt 0: 0.1 * 10^0 = 0.1
        #expect(policy.baseDelay(forAttempt: 0) == 0.1)

        // Attempt 1: 0.1 * 10^1 = 1.0 (capped at maxDelay)
        #expect(policy.baseDelay(forAttempt: 1) == 1.0)

        // Attempt 2: exhausted (maxAttempts = 2)
        #expect(policy.baseDelay(forAttempt: 2) == nil)

        // Zero jitter means delay() == baseDelay()
        #expect(
            policy.delay(forAttempt: 0)
                == policy.baseDelay(forAttempt: 0)
        )
    }
}
