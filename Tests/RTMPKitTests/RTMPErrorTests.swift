// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Creation

@Suite("RTMPError — Creation")
struct RTMPErrorCreationTests {

    @Test("every error case can be created")
    func allCasesCreatable() {
        let errors: [RTMPError] = [
            .connectionFailed("test"),
            .connectionTimeout,
            .connectionClosed,
            .tlsError("cert invalid"),
            .handshakeFailed("bad S0"),
            .versionMismatch(expected: 3, received: 4),
            .invalidChunkHeader,
            .invalidMessageType(99),
            .messageTooLarge(999_999),
            .connectRejected(code: "NetConnection.Connect.Rejected", description: "auth"),
            .createStreamFailed("no stream ID"),
            .publishFailed(code: "NetStream.Publish.Failed", description: "busy"),
            .unexpectedResponse("unknown response"),
            .transactionTimeout(transactionID: 42),
            .invalidState("wrong state"),
            .notConnected,
            .notPublishing,
            .alreadyPublishing,
            .reconnectExhausted(attempts: 5),
            .invalidURL("bad url")
        ]
        #expect(errors.count == 20)
    }

    @Test("localizedDescription is non-empty for each case")
    func localizedDescriptionNonEmpty() {
        let errors: [RTMPError] = [
            .connectionFailed("test"),
            .connectionTimeout,
            .connectionClosed,
            .tlsError("cert"),
            .handshakeFailed("bad"),
            .versionMismatch(expected: 3, received: 4),
            .invalidChunkHeader,
            .invalidMessageType(99),
            .messageTooLarge(999),
            .connectRejected(code: "code", description: "desc"),
            .createStreamFailed("fail"),
            .publishFailed(code: "code", description: "desc"),
            .unexpectedResponse("resp"),
            .transactionTimeout(transactionID: 1),
            .invalidState("state"),
            .notConnected,
            .notPublishing,
            .alreadyPublishing,
            .reconnectExhausted(attempts: 3),
            .invalidURL("url")
        ]
        for error in errors {
            #expect(!error.localizedDescription.isEmpty)
        }
    }
}

// MARK: - Equatable

@Suite("RTMPError — Equatable")
struct RTMPErrorEquatableTests {

    @Test("connectionFailed with same value is equal")
    func connectionFailedEqual() {
        #expect(
            RTMPError.connectionFailed("a") == RTMPError.connectionFailed("a")
        )
    }

    @Test("connectionFailed with different value is not equal")
    func connectionFailedNotEqual() {
        #expect(
            RTMPError.connectionFailed("a") != RTMPError.connectionFailed("b")
        )
    }

    @Test("connectionTimeout equals itself")
    func connectionTimeoutEqual() {
        #expect(RTMPError.connectionTimeout == RTMPError.connectionTimeout)
    }

    @Test("connectionTimeout not equal to connectionClosed")
    func connectionTimeoutNotEqualClosed() {
        #expect(RTMPError.connectionTimeout != RTMPError.connectionClosed)
    }

    @Test("versionMismatch equality")
    func versionMismatchEqual() {
        #expect(
            RTMPError.versionMismatch(expected: 3, received: 4)
                == RTMPError.versionMismatch(expected: 3, received: 4)
        )
        #expect(
            RTMPError.versionMismatch(expected: 3, received: 4)
                != RTMPError.versionMismatch(expected: 3, received: 5)
        )
    }

    @Test("publishFailed with same code and description is equal")
    func publishFailedEqual() {
        #expect(
            RTMPError.publishFailed(code: "a", description: "b")
                == RTMPError.publishFailed(code: "a", description: "b")
        )
    }

    @Test("publishFailed with different values is not equal")
    func publishFailedNotEqual() {
        #expect(
            RTMPError.publishFailed(code: "a", description: "b")
                != RTMPError.publishFailed(code: "a", description: "c")
        )
    }

    @Test("transactionTimeout with same ID is equal")
    func transactionTimeoutEqual() {
        #expect(
            RTMPError.transactionTimeout(transactionID: 1)
                == RTMPError.transactionTimeout(transactionID: 1)
        )
    }

    @Test("transactionTimeout with different ID is not equal")
    func transactionTimeoutNotEqual() {
        #expect(
            RTMPError.transactionTimeout(transactionID: 1)
                != RTMPError.transactionTimeout(transactionID: 2)
        )
    }

    @Test("reconnectExhausted with same attempts is equal")
    func reconnectExhaustedEqual() {
        #expect(
            RTMPError.reconnectExhausted(attempts: 5)
                == RTMPError.reconnectExhausted(attempts: 5)
        )
    }

    @Test("reconnectExhausted with different attempts is not equal")
    func reconnectExhaustedNotEqual() {
        #expect(
            RTMPError.reconnectExhausted(attempts: 5)
                != RTMPError.reconnectExhausted(attempts: 3)
        )
    }
}

// MARK: - Error Conformance

@Suite("RTMPError — Error Conformance")
struct RTMPErrorConformanceTests {

    @Test("can be thrown and caught")
    func throwAndCatch() {
        do {
            throw RTMPError.connectionTimeout
        } catch let error as RTMPError {
            #expect(error == .connectionTimeout)
        } catch {
            Issue.record("Expected RTMPError")
        }
    }

    @Test("pattern matching works for all cases")
    func patternMatching() {
        let error: RTMPError = .invalidURL("test")
        switch error {
        case .invalidURL(let msg):
            #expect(msg == "test")
        default:
            Issue.record("Pattern match failed")
        }
    }

    @Test("invalidURL has descriptive message")
    func invalidURLMessage() {
        let error = RTMPError.invalidURL("Missing rtmp:// scheme")
        if case .invalidURL(let msg) = error {
            #expect(msg.contains("scheme"))
        } else {
            Issue.record("Expected invalidURL")
        }
    }
}
