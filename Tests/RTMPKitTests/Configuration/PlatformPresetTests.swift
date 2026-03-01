// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Twitch

@Suite("PlatformPreset — Twitch")
struct PlatformPresetTwitchTests {

    @Test("twitch auto URL contains live.twitch.tv")
    func twitchAutoURL() {
        let preset = PlatformPreset.twitch(.auto)
        #expect(preset.url.contains("live.twitch.tv"))
    }

    @Test("twitch usEast URL contains iad05")
    func twitchUsEastURL() {
        let preset = PlatformPreset.twitch(.usEast)
        #expect(preset.url.contains("iad05"))
    }

    @Test("twitch requiresTLS is false")
    func twitchRequiresTLS() {
        let preset = PlatformPreset.twitch(.auto)
        #expect(preset.requiresTLS == false)
    }

    @Test("twitch supportsEnhancedRTMP is true")
    func twitchEnhancedRTMP() {
        let preset = PlatformPreset.twitch(.auto)
        #expect(preset.supportsEnhancedRTMP == true)
    }

    @Test("twitch chunkSize is 4096")
    func twitchChunkSize() {
        let preset = PlatformPreset.twitch(.auto)
        #expect(preset.chunkSize == 4096)
    }

    @Test("twitch maxBitrate is 8500")
    func twitchMaxBitrate() {
        let preset = PlatformPreset.twitch(.auto)
        #expect(preset.maxBitrate == 8500)
    }

    @Test("twitch flashVersion contains FMLE")
    func twitchFlashVersion() {
        let preset = PlatformPreset.twitch(.auto)
        #expect(preset.flashVersion.contains("FMLE"))
    }
}

// MARK: - YouTube

@Suite("PlatformPreset — YouTube")
struct PlatformPresetYouTubeTests {

    @Test("youtube URL matches ingestURL")
    func youtubeURL() {
        let url = "rtmps://a.rtmp.youtube.com/live2"
        let preset = PlatformPreset.youtube(ingestURL: url)
        #expect(preset.url == url)
    }

    @Test("youtube requiresTLS is true")
    func youtubeRequiresTLS() {
        let preset = PlatformPreset.youtube(
            ingestURL: "rtmps://a.rtmp.youtube.com/live2"
        )
        #expect(preset.requiresTLS == true)
    }

    @Test("youtube supportsEnhancedRTMP is true")
    func youtubeEnhancedRTMP() {
        let preset = PlatformPreset.youtube(
            ingestURL: "rtmps://a.rtmp.youtube.com/live2"
        )
        #expect(preset.supportsEnhancedRTMP == true)
    }

    @Test("youtube maxBitrate is 9000")
    func youtubeMaxBitrate() {
        let preset = PlatformPreset.youtube(
            ingestURL: "rtmps://a.rtmp.youtube.com/live2"
        )
        #expect(preset.maxBitrate == 9000)
    }
}

// MARK: - Facebook

@Suite("PlatformPreset — Facebook")
struct PlatformPresetFacebookTests {

    @Test("facebook URL contains facebook.com")
    func facebookURL() {
        let preset = PlatformPreset.facebook
        #expect(preset.url.contains("facebook.com"))
    }

    @Test("facebook requiresTLS is true")
    func facebookRequiresTLS() {
        #expect(PlatformPreset.facebook.requiresTLS == true)
    }

    @Test("facebook supportsEnhancedRTMP is false")
    func facebookEnhancedRTMP() {
        #expect(PlatformPreset.facebook.supportsEnhancedRTMP == false)
    }

    @Test("facebook maxBitrate is 4000")
    func facebookMaxBitrate() {
        #expect(PlatformPreset.facebook.maxBitrate == 4000)
    }
}

// MARK: - Kick

@Suite("PlatformPreset — Kick")
struct PlatformPresetKickTests {

    @Test("kick URL contains correct hostname")
    func kickURL() {
        let preset = PlatformPreset.kick
        #expect(preset.url.contains("global-contribute.live-video.net"))
    }

    @Test("kick requiresTLS is false")
    func kickRequiresTLS() {
        #expect(PlatformPreset.kick.requiresTLS == false)
    }

    @Test("kick supportsEnhancedRTMP is false")
    func kickEnhancedRTMP() {
        #expect(PlatformPreset.kick.supportsEnhancedRTMP == false)
    }

    @Test("kick maxBitrate is 8000")
    func kickMaxBitrate() {
        #expect(PlatformPreset.kick.maxBitrate == 8000)
    }
}

// MARK: - Equatable & General

@Suite("PlatformPreset — Equatable")
struct PlatformPresetEquatableTests {

    @Test("same presets are equal")
    func samePresetsEqual() {
        #expect(PlatformPreset.facebook == PlatformPreset.facebook)
        #expect(PlatformPreset.kick == PlatformPreset.kick)
        #expect(PlatformPreset.custom == PlatformPreset.custom)
        #expect(
            PlatformPreset.twitch(.auto) == PlatformPreset.twitch(.auto)
        )
    }

    @Test("different presets are not equal")
    func differentPresetsNotEqual() {
        #expect(PlatformPreset.facebook != PlatformPreset.kick)
        #expect(
            PlatformPreset.twitch(.auto) != PlatformPreset.twitch(.usEast)
        )
        #expect(PlatformPreset.facebook != PlatformPreset.custom)
    }

    @Test("audio recommendation is non-empty for all presets")
    func audioRecommendationNonEmpty() {
        let presets: [PlatformPreset] = [
            .twitch(.auto), .youtube(ingestURL: "rtmps://test"),
            .facebook, .kick, .custom
        ]
        for preset in presets {
            #expect(!preset.audioRecommendation.isEmpty)
        }
    }

    @Test("custom preset has empty URL")
    func customEmptyURL() {
        #expect(PlatformPreset.custom.url == "")
    }
}
