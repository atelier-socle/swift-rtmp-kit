// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("DestinationState — isActive")
struct DestinationStateIsActiveTests {

    @Test("streaming is active")
    func streamingIsActive() {
        #expect(DestinationState.streaming.isActive)
    }

    @Test("connecting is active")
    func connectingIsActive() {
        #expect(DestinationState.connecting.isActive)
    }

    @Test("reconnecting is active")
    func reconnectingIsActive() {
        #expect(DestinationState.reconnecting(attempt: 1).isActive)
    }

    @Test("idle is not active")
    func idleIsNotActive() {
        #expect(!DestinationState.idle.isActive)
    }

    @Test("stopped is not active")
    func stoppedIsNotActive() {
        #expect(!DestinationState.stopped.isActive)
    }

    @Test("failed is not active")
    func failedIsNotActive() {
        #expect(!DestinationState.failed(RTMPError.connectionClosed).isActive)
    }
}

@Suite("DestinationState — Equatable")
struct DestinationStateEquatableTests {

    @Test("idle equals idle")
    func idleEqualsIdle() {
        #expect(DestinationState.idle == .idle)
    }

    @Test("streaming equals streaming")
    func streamingEqualsStreaming() {
        #expect(DestinationState.streaming == .streaming)
    }

    @Test("reconnecting with same attempt is equal")
    func reconnectingSameAttempt() {
        #expect(DestinationState.reconnecting(attempt: 1) == .reconnecting(attempt: 1))
    }

    @Test("reconnecting with different attempt is not equal")
    func reconnectingDifferentAttempt() {
        #expect(DestinationState.reconnecting(attempt: 1) != .reconnecting(attempt: 2))
    }

    @Test("failed equals failed regardless of error")
    func failedEqualsFailedIgnoringError() {
        let a = DestinationState.failed(RTMPError.connectionClosed)
        let b = DestinationState.failed(RTMPError.connectionTimeout)
        #expect(a == b)
    }

    @Test("idle is not equal to streaming")
    func idleNotEqualToStreaming() {
        #expect(DestinationState.idle != .streaming)
    }

    @Test("all cases are distinct from each other")
    func allCasesDistinct() {
        let cases: [DestinationState] = [
            .idle, .connecting, .streaming,
            .reconnecting(attempt: 1), .stopped,
            .failed(RTMPError.connectionClosed)
        ]
        for i in 0..<cases.count {
            for j in (i + 1)..<cases.count {
                #expect(cases[i] != cases[j])
            }
        }
    }

    @Test("isActive is false for all terminal states")
    func terminalStatesNotActive() {
        let terminals: [DestinationState] = [
            .idle, .stopped, .failed(RTMPError.connectionClosed)
        ]
        for state in terminals {
            #expect(!state.isActive)
        }
    }
}
