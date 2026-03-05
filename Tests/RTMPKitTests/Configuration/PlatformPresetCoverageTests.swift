// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("PlatformPreset — Platform Properties")
struct PlatformPresetCoverageTests {

    @Test("platformName returns correct value for all presets")
    func platformNameAllCases() {
        #expect(PlatformPreset.instagram.platformName == "instagram")
        #expect(PlatformPreset.tiktok.platformName == "tiktok")
        #expect(PlatformPreset.twitter.platformName == "twitter")
        #expect(PlatformPreset.rumble.platformName == "rumble")
        #expect(PlatformPreset.linkedin.platformName == "linkedin")
        #expect(PlatformPreset.trovo.platformName == "trovo")
    }

    @Test("url returns correct value for additional presets")
    func urlAdditionalPresets() {
        #expect(PlatformPreset.instagram.url.contains("instagram.com"))
        #expect(PlatformPreset.tiktok.url.contains("tiktok.com"))
        #expect(PlatformPreset.twitter.url.contains("periscope"))
        #expect(PlatformPreset.rumble.url.contains("rumble.com"))
        #expect(PlatformPreset.linkedin.url.contains("linkedin.com"))
        #expect(PlatformPreset.trovo.url.contains("trovo.live"))
    }

    @Test("audioRecommendation returns correct value for additional presets")
    func audioRecommendationAdditionalPresets() {
        #expect(PlatformPreset.instagram.audioRecommendation.contains("AAC"))
        #expect(PlatformPreset.tiktok.audioRecommendation.contains("AAC"))
        #expect(PlatformPreset.twitter.audioRecommendation.contains("AAC"))
        #expect(PlatformPreset.rumble.audioRecommendation.contains("AAC"))
        #expect(PlatformPreset.linkedin.audioRecommendation.contains("AAC"))
        #expect(PlatformPreset.trovo.audioRecommendation.contains("AAC"))
    }
}
