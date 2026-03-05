// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Platform Presets Showcase — New Platforms")
struct PlatformPresetsShowcaseNewTests {

    @Test("Instagram Live requires RTMPS")
    func instagramLive() {
        let config = RTMPConfiguration.instagram(streamKey: "IGLive_abc123")
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.preset?.requiresTLS == true)
        #expect(config.enhancedRTMP == false)
    }

    @Test("TikTok Live configuration")
    func tiktokLive() {
        let config = RTMPConfiguration.tiktok(streamKey: "tiktok_stream_key")
        #expect(config.url.contains("tiktok.com"))
        #expect(config.preset?.requiresTLS == true)
    }

    @Test("Rumble uses plain RTMP (no TLS)")
    func rumblePlainRTMP() {
        let config = RTMPConfiguration.rumble(streamKey: "my_rumble_key")
        #expect(config.url.hasPrefix("rtmp://"))
        #expect(config.preset?.requiresTLS == false)
    }

    @Test("All TLS platforms use rtmps:// scheme")
    func allTLSPlatforms() {
        for preset in StreamingPlatformRegistry.tlsRequiredPlatforms {
            let config = StreamingPlatformRegistry.configuration(
                platform: preset.name, streamKey: "test"
            )
            #expect(config != nil)
            #expect(config?.url.hasPrefix("rtmps://") == true)
        }
    }

    @Test("Platform registry resolves names case-insensitively")
    func caseInsensitive() {
        #expect(StreamingPlatformRegistry.platform(named: "LinkedIn") == .linkedin)
        #expect(StreamingPlatformRegistry.platform(named: "TROVO") == .trovo)
        #expect(StreamingPlatformRegistry.platform(named: "xyz") == nil)
    }

    @Test("Configuration from registry includes stream key")
    func registryStreamKey() {
        let config = StreamingPlatformRegistry.configuration(
            platform: "twitter", streamKey: "periscope_key"
        )
        #expect(config != nil)
        #expect(config?.streamKey == "periscope_key")
    }
}

@Suite("Platform Presets Showcase — Multi-Platform Patterns")
struct PlatformPresetsShowcaseMultiTests {

    @Test("Add all 10 platforms to MultiPublisher")
    func allPlatformsMultiPublisher() async throws {
        let multi = MultiPublisher(
            transportFactory: { _ in MockTransport() }
        )
        for preset in StreamingPlatformRegistry.allPlatforms {
            guard
                let config = StreamingPlatformRegistry.configuration(
                    platform: preset.name, streamKey: "test_key"
                )
            else {
                Issue.record("Failed to create config for \(preset.name)")
                continue
            }
            try await multi.addDestination(
                PublishDestination(id: preset.name, configuration: config)
            )
        }
        let states = await multi.destinationStates
        #expect(states.count == 10)
    }

    @Test("All platforms have non-empty ingest URLs")
    func nonEmptyIngestURLs() {
        for preset in StreamingPlatformRegistry.allPlatforms {
            let config = StreamingPlatformRegistry.configuration(
                platform: preset.name, streamKey: "key"
            )
            #expect(config != nil)
            #expect(config?.url.isEmpty == false)
            #expect(config?.url.hasPrefix("rtmp") == true)
        }
    }

    @Test("TLS and non-TLS platforms coexist in MultiPublisher")
    func mixedTLSMultiPublisher() async throws {
        let multi = MultiPublisher(
            transportFactory: { _ in MockTransport() }
        )
        // Non-TLS
        let rumbleConfig = RTMPConfiguration.rumble(streamKey: "r_key")
        try await multi.addDestination(
            PublishDestination(id: "rumble", configuration: rumbleConfig)
        )
        // TLS
        let igConfig = RTMPConfiguration.instagram(streamKey: "ig_key")
        try await multi.addDestination(
            PublishDestination(id: "instagram", configuration: igConfig)
        )
        let states = await multi.destinationStates
        #expect(states.count == 2)
    }

    @Test("New platforms work with ABR and authentication")
    func newPlatformsWithABRAndAuth() {
        var config = RTMPConfiguration.tiktok(streamKey: "key")
        config.adaptiveBitrate = .responsive(min: 500_000, max: 4_000_000)
        config.authentication = .token("tiktok_auth_token")
        #expect(config.adaptiveBitrate == .responsive(min: 500_000, max: 4_000_000))
        if case .token(let token, _) = config.authentication {
            #expect(token == "tiktok_auth_token")
        } else {
            Issue.record("Expected .token authentication")
        }
    }
}
