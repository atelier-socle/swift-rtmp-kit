// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Publisher Showcase — State Machine")
struct PublisherStateMachineShowcaseTests {

    @Test("Full state lifecycle: idle → connecting → handshaking → connected → publishing → disconnected")
    func fullStateLifecycle() {
        var session = RTMPSession()
        #expect(session.state == .idle)

        let ok1 = session.transition(to: .connecting)
        #expect(ok1)
        #expect(session.state == .connecting)

        let ok2 = session.transition(to: .handshaking)
        #expect(ok2)
        #expect(session.state == .handshaking)

        let ok3 = session.transition(to: .connected)
        #expect(ok3)
        #expect(session.state == .connected)

        let ok4 = session.transition(to: .publishing)
        #expect(ok4)
        #expect(session.state == .publishing)

        let ok5 = session.transition(to: .disconnected)
        #expect(ok5)
        #expect(session.state == .disconnected)
    }

    @Test("State machine rejects invalid transitions")
    func rejectsInvalidTransitions() {
        var session = RTMPSession()

        // idle → publishing is not valid
        #expect(!session.canTransition(to: .publishing))

        // idle → connected is not valid
        #expect(!session.canTransition(to: .connected))
    }

    @Test("Disconnect is idempotent")
    func disconnectIdempotent() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)
        session.transition(to: .disconnected)

        // Second disconnect attempt — already disconnected
        let ok = session.transition(to: .disconnected)
        #expect(session.state == .disconnected)
        // Whether it returns true or false, state must remain .disconnected
        _ = ok
    }

    @Test("Reconnection sequence via state machine")
    func reconnectionSequence() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)

        // Simulate reconnection
        let reconnectOK = session.transition(to: .reconnecting(attempt: 1))
        if reconnectOK {
            #expect(session.state == .reconnecting(attempt: 1))
            // After exhausted attempts → failed
            session.transition(to: .failed(.reconnectExhausted(attempts: 5)))
            if case .failed = session.state {
                // OK — expected
            } else {
                Issue.record("Expected .failed state")
            }
        }
    }
}

@Suite("Publisher Showcase — Platform Presets")
struct PublisherPresetShowcaseTests {

    @Test("Twitch preset creates correct configuration")
    func twitchPreset() {
        let config = RTMPConfiguration.twitch(streamKey: "live_test_key")
        #expect(config.streamKey == "live_test_key")
        #expect(config.enhancedRTMP == true)
        #expect(config.chunkSize == 4096)
        #expect(config.url.contains("twitch.tv"))
    }

    @Test("YouTube preset creates correct configuration")
    func youtubePreset() {
        let config = RTMPConfiguration.youtube(streamKey: "yt_key")
        #expect(config.streamKey == "yt_key")
        #expect(config.url.contains("youtube.com"))
    }

    @Test("Facebook preset creates correct configuration")
    func facebookPreset() {
        let config = RTMPConfiguration.facebook(streamKey: "fb_key")
        #expect(config.streamKey == "fb_key")
    }

    @Test("Kick preset creates correct configuration")
    func kickPreset() {
        let config = RTMPConfiguration.kick(streamKey: "kick_key")
        #expect(config.streamKey == "kick_key")
    }
}

@Suite("Publisher Showcase — StreamKey URL Parsing")
struct PublisherStreamKeyShowcaseTests {

    @Test("StreamKey URL parsing for Twitch")
    func parseTwitchURL() throws {
        let key = try StreamKey(
            url: "rtmps://live.twitch.tv/app", streamKey: "live_key")
        #expect(key.host == "live.twitch.tv")
        #expect(key.useTLS == true)
        #expect(key.port == 443)
        #expect(key.app == "app")
    }

    @Test("StreamKey URL parsing for YouTube")
    func parseYouTubeURL() throws {
        let key = try StreamKey(
            url: "rtmps://a.rtmp.youtube.com/live2", streamKey: "yt_key")
        #expect(key.host == "a.rtmp.youtube.com")
        #expect(key.useTLS == true)
        #expect(key.app == "live2")
    }

    @Test("StreamKey with RTMP (non-TLS)")
    func parseRTMPURL() throws {
        let key = try StreamKey(
            url: "rtmp://server.example.com/live", streamKey: "key")
        #expect(key.host == "server.example.com")
        #expect(key.useTLS == false)
        #expect(key.port == 1935)
    }

    @Test("StreamKey with non-standard port")
    func nonStandardPort() throws {
        let key = try StreamKey(
            url: "rtmp://server:9999/live", streamKey: "key")
        #expect(key.port == 9999)
    }

    @Test("StreamKey with invalid URL fails")
    func invalidURLFails() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(url: "not-a-url", streamKey: "key")
        }
    }
}

@Suite("Publisher Showcase — Transaction ID & Ack")
struct PublisherTransactionShowcaseTests {

    @Test("Transaction ID management: sequential allocation and tracking")
    func transactionIDManagement() {
        var conn = RTMPConnection()

        // Allocate 5 IDs → 1,2,3,4,5
        let ids = (0..<5).map { _ in conn.allocateTransactionID() }
        #expect(ids == [1, 2, 3, 4, 5])

        // Track pending
        conn.registerPendingCommand(transactionID: 1, commandName: "connect")
        conn.registerPendingCommand(transactionID: 2, commandName: "createStream")
        #expect(conn.hasPendingTransaction(1))
        #expect(conn.hasPendingTransaction(2))

        // Resolve
        let name1 = conn.processResponse(transactionID: 1)
        #expect(name1 == "connect")
        #expect(!conn.hasPendingTransaction(1))
        #expect(conn.hasPendingTransaction(2))
    }

    @Test("Acknowledgement byte tracking")
    func ackByteTracking() {
        var conn = RTMPConnection()
        conn.setWindowAckSize(2500)

        // Under threshold
        let r1 = conn.addBytesReceived(1000)
        #expect(r1 == nil)

        let r2 = conn.addBytesReceived(1000)
        #expect(r2 == nil)

        // Exceeds threshold (2000 + 600 = 2600 > 2500)
        let r3 = conn.addBytesReceived(600)
        #expect(r3 != nil)
        #expect(r3 == 2600)

        // After ack, need another 2500 bytes
        let r4 = conn.addBytesReceived(2000)
        #expect(r4 == nil)

        let r5 = conn.addBytesReceived(600)
        #expect(r5 != nil)
        #expect(r5 == 5200)
    }
}

@Suite("Publisher Showcase — ReconnectPolicy")
struct PublisherReconnectPolicyShowcaseTests {

    @Test("Exponential backoff delays")
    func exponentialBackoff() {
        let policy = ReconnectPolicy.default
        // Default: initialDelay=1.0, multiplier=2.0, maxDelay=30.0, maxAttempts=5

        let d0 = policy.baseDelay(forAttempt: 0)
        let d1 = policy.baseDelay(forAttempt: 1)
        let d2 = policy.baseDelay(forAttempt: 2)
        let d3 = policy.baseDelay(forAttempt: 3)
        let d4 = policy.baseDelay(forAttempt: 4)
        let d5 = policy.baseDelay(forAttempt: 5)

        #expect(d0 == 1.0)
        #expect(d1 == 2.0)
        #expect(d2 == 4.0)
        #expect(d3 == 8.0)
        #expect(d4 == 16.0)
        // Attempt 5 exceeds maxAttempts → nil (exhausted)
        #expect(d5 == nil)
    }

    @Test("Reconnection exhausted returns nil delay")
    func exhaustedReturnsNil() {
        let policy = ReconnectPolicy(maxAttempts: 3)
        #expect(policy.baseDelay(forAttempt: 0) != nil)
        #expect(policy.baseDelay(forAttempt: 1) != nil)
        #expect(policy.baseDelay(forAttempt: 2) != nil)
        #expect(policy.baseDelay(forAttempt: 3) == nil)
    }
}
