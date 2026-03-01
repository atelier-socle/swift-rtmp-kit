// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("StreamKey — Parsing")
struct StreamKeyParsingTests {

    @Test("Parse rtmp URL with separate stream key")
    func parseRTMPWithSeparateKey() throws {
        let sk = try StreamKey(url: "rtmp://live.twitch.tv/app", streamKey: "live_xxx")
        #expect(sk.host == "live.twitch.tv")
        #expect(sk.port == 1935)
        #expect(!sk.useTLS)
        #expect(sk.app == "app")
        #expect(sk.key == "live_xxx")
    }

    @Test("Parse rtmps URL with separate stream key")
    func parseRTMPSWithSeparateKey() throws {
        let sk = try StreamKey(
            url: "rtmps://a.rtmp.youtube.com/live2",
            streamKey: "xxxx-xxxx"
        )
        #expect(sk.host == "a.rtmp.youtube.com")
        #expect(sk.port == 443)
        #expect(sk.useTLS)
        #expect(sk.app == "live2")
        #expect(sk.key == "xxxx-xxxx")
    }

    @Test("Parse with explicit port")
    func parseExplicitPort() throws {
        let sk = try StreamKey(url: "rtmp://host:19350/app", streamKey: "key")
        #expect(sk.host == "host")
        #expect(sk.port == 19350)
    }

    @Test("Parse combined URL splits app and key")
    func parseCombinedURL() throws {
        let sk = try StreamKey(combinedURL: "rtmp://host/app/mykey")
        #expect(sk.app == "app")
        #expect(sk.key == "mykey")
    }

    @Test("Parse combined URL with multi-segment key")
    func parseCombinedMultiSegmentKey() throws {
        let sk = try StreamKey(combinedURL: "rtmp://host:19350/app/instance/mykey")
        #expect(sk.host == "host")
        #expect(sk.port == 19350)
        #expect(sk.app == "app")
        #expect(sk.key == "instance/mykey")
    }

    @Test("tcUrl is reconstructed correctly")
    func tcUrlReconstructed() throws {
        let sk = try StreamKey(url: "rtmp://live.twitch.tv/app", streamKey: "k")
        #expect(sk.tcUrl == "rtmp://live.twitch.tv:1935/app")
    }

    @Test("tcUrl for rtmps includes port 443")
    func tcUrlRTMPS() throws {
        let sk = try StreamKey(
            url: "rtmps://a.rtmp.youtube.com/live2",
            streamKey: "k"
        )
        #expect(sk.tcUrl == "rtmps://a.rtmp.youtube.com:443/live2")
    }

    @Test("Twitch URL format")
    func twitchFormat() throws {
        let sk = try StreamKey(
            url: "rtmp://live.twitch.tv/app",
            streamKey: "live_123456789_abcdef"
        )
        #expect(sk.host == "live.twitch.tv")
        #expect(sk.app == "app")
        #expect(sk.key == "live_123456789_abcdef")
    }

    @Test("YouTube URL format (rtmps with subdomains)")
    func youtubeFormat() throws {
        let sk = try StreamKey(
            url: "rtmps://a.rtmp.youtube.com/live2",
            streamKey: "xxxx-xxxx-xxxx-xxxx"
        )
        #expect(sk.host == "a.rtmp.youtube.com")
        #expect(sk.useTLS)
        #expect(sk.app == "live2")
    }

    @Test("Facebook URL format")
    func facebookFormat() throws {
        let sk = try StreamKey(
            url: "rtmps://live-api-s.facebook.com/rtmp",
            streamKey: "FB-123456789"
        )
        #expect(sk.host == "live-api-s.facebook.com")
        #expect(sk.useTLS)
        #expect(sk.app == "rtmp")
    }

    @Test("Kick URL format")
    func kickFormat() throws {
        let sk = try StreamKey(
            url: "rtmps://fa723fc1b171.global-contribute.live-video.net/app",
            streamKey: "sk_us-east-1_abc123"
        )
        #expect(sk.host == "fa723fc1b171.global-contribute.live-video.net")
        #expect(sk.app == "app")
    }
}

@Suite("StreamKey — Errors")
struct StreamKeyErrorTests {

    @Test("Missing scheme throws invalidURL")
    func missingScheme() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(url: "http://host/app", streamKey: "key")
        }
    }

    @Test("Missing host throws invalidURL")
    func missingHost() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(url: "rtmp:///app", streamKey: "key")
        }
    }

    @Test("Missing app throws invalidURL")
    func missingApp() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(url: "rtmp://host", streamKey: "key")
        }
    }

    @Test("Empty stream key throws invalidURL")
    func emptyStreamKey() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(url: "rtmp://host/app", streamKey: "")
        }
    }

    @Test("Combined URL missing key throws invalidURL")
    func combinedMissingKey() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(combinedURL: "rtmp://host/app")
        }
    }
}

@Suite("StreamKey — Edge Cases")
struct StreamKeyEdgeCaseTests {

    @Test("URL with trailing slash")
    func trailingSlash() throws {
        let sk = try StreamKey(url: "rtmp://host/app/", streamKey: "key")
        #expect(sk.app == "app")
    }

    @Test("URL with query parameters ignored")
    func queryParamsIgnored() throws {
        let sk = try StreamKey(url: "rtmp://host/app?token=abc", streamKey: "key")
        #expect(sk.app == "app")
    }

    @Test("Port defaults: 1935 for rtmp")
    func defaultPortRTMP() throws {
        let sk = try StreamKey(url: "rtmp://host/app", streamKey: "key")
        #expect(sk.port == 1935)
    }

    @Test("Port defaults: 443 for rtmps")
    func defaultPortRTMPS() throws {
        let sk = try StreamKey(url: "rtmps://host/app", streamKey: "key")
        #expect(sk.port == 443)
    }

    @Test("Equatable: same URL and key are equal")
    func equatable() throws {
        let a = try StreamKey(url: "rtmp://host/app", streamKey: "key")
        let b = try StreamKey(url: "rtmp://host/app", streamKey: "key")
        #expect(a == b)
    }

    @Test("Equatable: different keys are not equal")
    func notEquatable() throws {
        let a = try StreamKey(url: "rtmp://host/app", streamKey: "key1")
        let b = try StreamKey(url: "rtmp://host/app", streamKey: "key2")
        #expect(a != b)
    }

    @Test("Explicit port overrides default")
    func explicitPortOverride() throws {
        let sk = try StreamKey(url: "rtmps://host:8443/app", streamKey: "key")
        #expect(sk.port == 8443)
    }
}
