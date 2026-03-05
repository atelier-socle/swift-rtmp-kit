// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("StreamingPlatformRegistry")
struct StreamingPlatformRegistryTests {

    @Test("allPlatforms contains 10 platforms")
    func allPlatformsCount() {
        #expect(StreamingPlatformRegistry.allPlatforms.count == 10)
    }

    @Test("allPlatforms is sorted alphabetically by name")
    func allPlatformsSorted() {
        let names = StreamingPlatformRegistry.allPlatforms.map(\.name)
        #expect(names == names.sorted())
    }

    @Test("tlsRequiredPlatforms contains all TLS platforms")
    func tlsRequired() {
        let names = StreamingPlatformRegistry.tlsRequiredPlatforms.map(\.name)
        #expect(names.contains("Facebook"))
        #expect(names.contains("Instagram"))
        #expect(names.contains("LinkedIn"))
        #expect(names.contains("TikTok"))
        #expect(names.contains("Twitter"))
        #expect(names.contains("YouTube"))
    }

    @Test("tlsRequiredPlatforms excludes non-TLS platforms")
    func tlsExclusions() {
        let names = StreamingPlatformRegistry.tlsRequiredPlatforms.map(\.name)
        #expect(!names.contains("Rumble"))
        #expect(!names.contains("Trovo"))
        #expect(!names.contains("Kick"))
    }

    @Test("enhancedRTMPPlatforms contains Twitch and YouTube")
    func enhancedRTMP() {
        let names = StreamingPlatformRegistry.enhancedRTMPPlatforms.map(\.name)
        #expect(names.contains("Twitch"))
        #expect(names.contains("YouTube"))
        #expect(names.count == 2)
    }

    @Test("platform(named:) resolves case-insensitively")
    func platformNamed() {
        #expect(StreamingPlatformRegistry.platform(named: "instagram") == .instagram)
        #expect(StreamingPlatformRegistry.platform(named: "TIKTOK") == .tiktok)
        #expect(StreamingPlatformRegistry.platform(named: "LinkedIn") == .linkedin)
        #expect(StreamingPlatformRegistry.platform(named: "Twitch") == .twitch(.auto))
    }

    @Test("platform(named:) returns nil for unknown")
    func platformUnknown() {
        #expect(StreamingPlatformRegistry.platform(named: "unknown") == nil)
        #expect(StreamingPlatformRegistry.platform(named: "") == nil)
    }

    @Test("configuration builds valid config with stream key")
    func configurationBuild() {
        let config = StreamingPlatformRegistry.configuration(
            platform: "rumble", streamKey: "mykey"
        )
        #expect(config != nil)
        #expect(config?.url.contains("rumble.com") == true)
        #expect(config?.streamKey == "mykey")
        #expect(config?.enhancedRTMP == false)
    }

    @Test("configuration returns nil for unknown platform")
    func configurationUnknown() {
        #expect(StreamingPlatformRegistry.configuration(platform: "xyz", streamKey: "k") == nil)
    }
}
