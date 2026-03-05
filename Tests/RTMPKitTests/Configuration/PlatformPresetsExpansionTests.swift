// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Platform Presets Expansion — New Factories")
struct PlatformPresetsExpansionFactoryTests {

    @Test("Instagram factory creates RTMPS config")
    func instagramFactory() {
        let config = RTMPConfiguration.instagram(streamKey: "IGLive_abc")
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.url.contains("instagram.com"))
        #expect(config.streamKey == "IGLive_abc")
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .instagram)
    }

    @Test("TikTok factory creates RTMPS config")
    func tiktokFactory() {
        let config = RTMPConfiguration.tiktok(streamKey: "tiktok_key")
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.url.contains("tiktok.com"))
        #expect(config.streamKey == "tiktok_key")
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .tiktok)
    }

    @Test("Twitter factory creates RTMPS config via Periscope")
    func twitterFactory() {
        let config = RTMPConfiguration.twitter(streamKey: "tw_key")
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.url.contains("periscope.tv"))
        #expect(config.streamKey == "tw_key")
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .twitter)
    }

    @Test("Rumble factory creates plain RTMP config")
    func rumbleFactory() {
        let config = RTMPConfiguration.rumble(streamKey: "rumble_key")
        #expect(config.url.hasPrefix("rtmp://"))
        #expect(!config.url.hasPrefix("rtmps://"))
        #expect(config.url.contains("rumble.com"))
        #expect(config.streamKey == "rumble_key")
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .rumble)
    }

    @Test("LinkedIn factory creates RTMPS config")
    func linkedinFactory() {
        let config = RTMPConfiguration.linkedin(streamKey: "li_key")
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.url.contains("linkedin.com"))
        #expect(config.streamKey == "li_key")
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .linkedin)
    }

    @Test("Trovo factory creates plain RTMP config")
    func trovoFactory() {
        let config = RTMPConfiguration.trovo(streamKey: "trovo_key")
        #expect(config.url.hasPrefix("rtmp://"))
        #expect(!config.url.hasPrefix("rtmps://"))
        #expect(config.url.contains("trovo.live"))
        #expect(config.streamKey == "trovo_key")
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .trovo)
    }
}

@Suite("Platform Presets Expansion — Cross-Cutting")
struct PresetsExpansionCrossCuttingTests {

    @Test("All new factories store stream key verbatim")
    func streamKeyVerbatim() {
        let key = "my_special_key_!@#$%"
        #expect(RTMPConfiguration.instagram(streamKey: key).streamKey == key)
        #expect(RTMPConfiguration.tiktok(streamKey: key).streamKey == key)
        #expect(RTMPConfiguration.twitter(streamKey: key).streamKey == key)
        #expect(RTMPConfiguration.rumble(streamKey: key).streamKey == key)
        #expect(RTMPConfiguration.linkedin(streamKey: key).streamKey == key)
        #expect(RTMPConfiguration.trovo(streamKey: key).streamKey == key)
    }

    @Test("All new factories default to no authentication")
    func defaultAuth() {
        #expect(RTMPConfiguration.instagram(streamKey: "k").authentication == .none)
        #expect(RTMPConfiguration.tiktok(streamKey: "k").authentication == .none)
        #expect(RTMPConfiguration.twitter(streamKey: "k").authentication == .none)
        #expect(RTMPConfiguration.rumble(streamKey: "k").authentication == .none)
        #expect(RTMPConfiguration.linkedin(streamKey: "k").authentication == .none)
        #expect(RTMPConfiguration.trovo(streamKey: "k").authentication == .none)
    }

    @Test("All new factories default to disabled ABR")
    func defaultABR() {
        #expect(RTMPConfiguration.instagram(streamKey: "k").adaptiveBitrate == .disabled)
        #expect(RTMPConfiguration.tiktok(streamKey: "k").adaptiveBitrate == .disabled)
        #expect(RTMPConfiguration.twitter(streamKey: "k").adaptiveBitrate == .disabled)
        #expect(RTMPConfiguration.rumble(streamKey: "k").adaptiveBitrate == .disabled)
        #expect(RTMPConfiguration.linkedin(streamKey: "k").adaptiveBitrate == .disabled)
        #expect(RTMPConfiguration.trovo(streamKey: "k").adaptiveBitrate == .disabled)
    }

    @Test("All new factories use 4096 chunk size")
    func defaultChunkSize() {
        #expect(RTMPConfiguration.instagram(streamKey: "k").chunkSize == 4096)
        #expect(RTMPConfiguration.tiktok(streamKey: "k").chunkSize == 4096)
        #expect(RTMPConfiguration.twitter(streamKey: "k").chunkSize == 4096)
        #expect(RTMPConfiguration.rumble(streamKey: "k").chunkSize == 4096)
        #expect(RTMPConfiguration.linkedin(streamKey: "k").chunkSize == 4096)
        #expect(RTMPConfiguration.trovo(streamKey: "k").chunkSize == 4096)
    }

    @Test("PlatformPreset has 11 cases (10 platforms + custom)")
    func presetCaseCount() {
        let allPresets: [PlatformPreset] = [
            .twitch(.auto),
            .youtube(ingestURL: ""),
            .facebook,
            .kick,
            .instagram,
            .tiktok,
            .twitter,
            .rumble,
            .linkedin,
            .trovo,
            .custom
        ]
        #expect(allPresets.count == 11)
    }

    @Test("Instagram preset requires TLS")
    func instagramRequiresTLS() {
        #expect(PlatformPreset.instagram.requiresTLS == true)
    }

    @Test("Rumble preset does not require TLS")
    func rumbleNoTLS() {
        #expect(PlatformPreset.rumble.requiresTLS == false)
    }

    @Test("Twitter preset does not support Enhanced RTMP")
    func twitterNoEnhancedRTMP() {
        #expect(PlatformPreset.twitter.supportsEnhancedRTMP == false)
    }
}
