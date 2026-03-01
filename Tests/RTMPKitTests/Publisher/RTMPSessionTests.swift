// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPSession — Valid Transitions")
struct RTMPSessionValidTransitionTests {

    @Test("idle → connecting")
    func idleToConnecting() {
        var session = RTMPSession()
        let ok = session.transition(to: .connecting)
        #expect(ok)
        #expect(session.state == .connecting)
    }

    @Test("connecting → handshaking")
    func connectingToHandshaking() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        let ok = session.transition(to: .handshaking)
        #expect(ok)
        #expect(session.state == .handshaking)
    }

    @Test("connecting → failed")
    func connectingToFailed() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        let ok = session.transition(to: .failed(.connectionTimeout))
        #expect(ok)
    }

    @Test("handshaking → connected")
    func handshakingToConnected() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        let ok = session.transition(to: .connected)
        #expect(ok)
        #expect(session.state == .connected)
    }

    @Test("handshaking → failed")
    func handshakingToFailed() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        let ok = session.transition(to: .failed(.handshakeFailed("timeout")))
        #expect(ok)
    }

    @Test("connected → publishing")
    func connectedToPublishing() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        let ok = session.transition(to: .publishing)
        #expect(ok)
        #expect(session.state == .publishing)
    }

    @Test("publishing → disconnected")
    func publishingToDisconnected() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)
        let ok = session.transition(to: .disconnected)
        #expect(ok)
    }

    @Test("publishing → reconnecting(1)")
    func publishingToReconnecting() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)
        let ok = session.transition(to: .reconnecting(attempt: 1))
        #expect(ok)
    }

    @Test("reconnecting → connecting (retry)")
    func reconnectingToConnecting() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)
        session.transition(to: .reconnecting(attempt: 1))
        let ok = session.transition(to: .connecting)
        #expect(ok)
    }

    @Test("reconnecting → failed (exhausted)")
    func reconnectingToFailed() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)
        session.transition(to: .reconnecting(attempt: 3))
        let ok = session.transition(
            to: .failed(.reconnectExhausted(attempts: 3))
        )
        #expect(ok)
    }
}

@Suite("RTMPSession — Invalid Transitions")
struct RTMPSessionInvalidTransitionTests {

    @Test("idle → publishing is rejected")
    func idleToPublishing() {
        var session = RTMPSession()
        let ok = session.transition(to: .publishing)
        #expect(!ok)
        #expect(session.state == .idle)
    }

    @Test("idle → connected is rejected")
    func idleToConnected() {
        var session = RTMPSession()
        let ok = session.transition(to: .connected)
        #expect(!ok)
    }

    @Test("connecting → publishing is rejected")
    func connectingToPublishing() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        let ok = session.transition(to: .publishing)
        #expect(!ok)
    }

    @Test("publishing → connecting is rejected")
    func publishingToConnecting() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)
        let ok = session.transition(to: .connecting)
        #expect(!ok)
    }

    @Test("disconnected → publishing is rejected")
    func disconnectedToPublishing() {
        var session = RTMPSession()
        session.transition(to: .disconnected)
        let ok = session.transition(to: .publishing)
        #expect(!ok)
    }
}

@Suite("RTMPSession — Force Transitions & Reset")
struct RTMPSessionForceTransitionTests {

    @Test("Any state → disconnected is always valid")
    func anyStateToDisconnected() {
        // Verify from connecting.
        var s1 = RTMPSession()
        s1.transition(to: .connecting)
        let ok1 = s1.transition(to: .disconnected)
        #expect(ok1)

        // Verify from publishing.
        var s2 = RTMPSession()
        s2.transition(to: .connecting)
        s2.transition(to: .handshaking)
        s2.transition(to: .connected)
        s2.transition(to: .publishing)
        let ok2 = s2.transition(to: .disconnected)
        #expect(ok2)

        // Verify from idle.
        var s3 = RTMPSession()
        let ok3 = s3.transition(to: .disconnected)
        #expect(ok3)
    }

    @Test("failed → idle via reset()")
    func failedToIdleViaReset() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .failed(.connectionTimeout))
        session.reset()
        #expect(session.state == .idle)
    }

    @Test("disconnected → idle via reset()")
    func disconnectedToIdleViaReset() {
        var session = RTMPSession()
        session.transition(to: .disconnected)
        session.reset()
        #expect(session.state == .idle)
    }

    @Test("canTransition returns true for valid")
    func canTransitionValid() {
        let session = RTMPSession()
        #expect(session.canTransition(to: .connecting))
    }

    @Test("canTransition returns false for invalid")
    func canTransitionInvalid() {
        let session = RTMPSession()
        #expect(!session.canTransition(to: .publishing))
    }

    @Test("Initial state is idle")
    func initialStateIdle() {
        let session = RTMPSession()
        #expect(session.state == .idle)
    }

    @Test("Reset returns to idle from publishing")
    func resetFromPublishing() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)
        session.reset()
        #expect(session.state == .idle)
    }

    @Test("publishing → failed")
    func publishingToFailed() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)
        let ok = session.transition(to: .failed(.connectionClosed))
        #expect(ok)
    }

    @Test("reconnecting → disconnected")
    func reconnectingToDisconnected() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        session.transition(to: .handshaking)
        session.transition(to: .connected)
        session.transition(to: .publishing)
        session.transition(to: .reconnecting(attempt: 1))
        let ok = session.transition(to: .disconnected)
        #expect(ok)
    }

    @Test("connecting → disconnected")
    func connectingToDisconnected() {
        var session = RTMPSession()
        session.transition(to: .connecting)
        let ok = session.transition(to: .disconnected)
        #expect(ok)
    }
}
