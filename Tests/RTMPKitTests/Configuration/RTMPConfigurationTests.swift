// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Init

@Suite("RTMPConfiguration — Init")
struct RTMPConfigurationInitTests {

    @Test("default init has correct default values")
    func defaultInitValues() {
        let config = RTMPConfiguration(
            url: "rtmp://localhost/app", streamKey: "key"
        )
        #expect(config.url == "rtmp://localhost/app")
        #expect(config.streamKey == "key")
        #expect(config.chunkSize == 4096)
        #expect(config.enhancedRTMP == true)
        #expect(config.reconnectPolicy == .default)
        #expect(config.preset == nil)
        #expect(config.metadata == nil)
        #expect(config.flashVersion == "FMLE/3.0 (compatible; FMSc/1.0)")
        #expect(config.transportConfiguration == .default)
    }

    @Test("custom init sets all parameters")
    func customInit() {
        let config = RTMPConfiguration(
            url: "rtmps://custom.host/live",
            streamKey: "secret",
            chunkSize: 8192,
            enhancedRTMP: false,
            reconnectPolicy: .aggressive,
            flashVersion: "CustomEncoder/1.0",
            transportConfiguration: .lowLatency
        )
        #expect(config.url == "rtmps://custom.host/live")
        #expect(config.streamKey == "secret")
        #expect(config.chunkSize == 8192)
        #expect(config.enhancedRTMP == false)
        #expect(config.reconnectPolicy == .aggressive)
        #expect(config.flashVersion == "CustomEncoder/1.0")
        #expect(config.transportConfiguration == .lowLatency)
    }

    @Test("url and streamKey stored correctly")
    func urlAndStreamKey() {
        let config = RTMPConfiguration(
            url: "rtmp://example.com/app", streamKey: "my_key_123"
        )
        #expect(config.url == "rtmp://example.com/app")
        #expect(config.streamKey == "my_key_123")
    }
}

// MARK: - Factory Methods

@Suite("RTMPConfiguration — Factory Methods")
struct RTMPConfigurationFactoryTests {

    @Test("twitch factory creates correct config")
    func twitchFactory() {
        let config = RTMPConfiguration.twitch(streamKey: "live_xxx")
        #expect(config.url.contains("live.twitch.tv"))
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.streamKey == "live_xxx")
        #expect(config.enhancedRTMP == true)
        #expect(config.preset == .twitch(.auto))
    }

    @Test("twitch with usEast ingest server")
    func twitchUsEast() {
        let config = RTMPConfiguration.twitch(
            streamKey: "live_xxx", ingestServer: .usEast
        )
        #expect(config.url.contains("iad05"))
        #expect(config.preset == .twitch(.usEast))
    }

    @Test("twitch with useTLS false uses rtmp://")
    func twitchNoTLS() {
        let config = RTMPConfiguration.twitch(
            streamKey: "live_xxx", useTLS: false
        )
        #expect(config.url.hasPrefix("rtmp://"))
        #expect(!config.url.hasPrefix("rtmps://"))
    }

    @Test("youtube factory creates correct config")
    func youtubeFactory() {
        let config = RTMPConfiguration.youtube(streamKey: "xxxx-xxxx")
        #expect(config.url == "rtmps://a.rtmp.youtube.com/live2")
        #expect(config.streamKey == "xxxx-xxxx")
        #expect(config.enhancedRTMP == true)
        #expect(
            config.preset
                == .youtube(ingestURL: "rtmps://a.rtmp.youtube.com/live2")
        )
    }

    @Test("youtube with custom ingest URL")
    func youtubeCustomURL() {
        let custom = "rtmps://custom.youtube.com/live"
        let config = RTMPConfiguration.youtube(
            streamKey: "key", ingestURL: custom
        )
        #expect(config.url == custom)
        #expect(config.preset == .youtube(ingestURL: custom))
    }

    @Test("facebook factory creates correct config")
    func facebookFactory() {
        let config = RTMPConfiguration.facebook(streamKey: "fb_key")
        #expect(config.url.contains("facebook.com"))
        #expect(config.url.hasPrefix("rtmps://"))
        #expect(config.streamKey == "fb_key")
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .facebook)
    }

    @Test("kick factory creates correct config")
    func kickFactory() {
        let config = RTMPConfiguration.kick(streamKey: "kick_key")
        #expect(config.url.contains("global-contribute.live-video.net"))
        #expect(config.streamKey == "kick_key")
        #expect(config.enhancedRTMP == false)
        #expect(config.preset == .kick)
    }

    @Test("kick with custom ingest URL")
    func kickCustomURL() {
        let custom = "rtmp://custom.kick.server/app"
        let config = RTMPConfiguration.kick(
            streamKey: "key", ingestURL: custom
        )
        #expect(config.url == custom)
    }
}

// MARK: - Integration

@Suite("RTMPConfiguration — Integration")
struct RTMPConfigurationIntegrationTests {

    @Test("transportConfiguration defaults to .default")
    func transportDefault() {
        let config = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key"
        )
        #expect(config.transportConfiguration == .default)
    }

    @Test("reconnectPolicy defaults to .default")
    func reconnectDefault() {
        let config = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key"
        )
        #expect(config.reconnectPolicy == .default)
    }

    @Test("metadata defaults to nil")
    func metadataDefault() {
        let config = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key"
        )
        #expect(config.metadata == nil)
    }

    @Test("metadata can be set")
    func metadataCanBeSet() {
        var config = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key"
        )
        var meta = StreamMetadata()
        meta.width = 1920
        meta.height = 1080
        config.metadata = meta
        #expect(config.metadata?.width == 1920)
        #expect(config.metadata?.height == 1080)
    }

    @Test("flashVersion defaults to FMLE string")
    func flashVersionDefault() {
        let config = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key"
        )
        #expect(config.flashVersion.contains("FMLE"))
    }
}

// MARK: - Equatable

@Suite("RTMPConfiguration — Equatable")
struct RTMPConfigurationEquatableTests {

    @Test("same configs are equal")
    func sameConfigsEqual() {
        let a = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key"
        )
        let b = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key"
        )
        #expect(a == b)
    }

    @Test("different configs are not equal")
    func differentConfigsNotEqual() {
        let a = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key1"
        )
        let b = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key2"
        )
        #expect(a != b)
    }

    @Test("streamKey comparison works")
    func streamKeyComparison() {
        var a = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key"
        )
        let b = RTMPConfiguration(
            url: "rtmp://host/app", streamKey: "key"
        )
        #expect(a == b)
        a.streamKey = "different"
        #expect(a != b)
    }

    @Test("factory configs with same params are equal")
    func factoryConfigsEqual() {
        let a = RTMPConfiguration.twitch(streamKey: "key")
        let b = RTMPConfiguration.twitch(streamKey: "key")
        #expect(a == b)
    }
}
