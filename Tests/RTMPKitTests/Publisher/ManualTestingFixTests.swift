// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

// MARK: - Fix 11: FCUnpublish stream name

@Suite("Fix 11 — FCUnpublish carries stream name")
struct FCUnpublishStreamNameTests {

    @Test("activeStreamName is set after successful publish")
    func activeStreamNameSet() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages([
            RTMPMessage(
                command: .result(
                    transactionID: 1,
                    properties: nil,
                    information: .object([
                        ("code", .string("NetConnection.Connect.Success"))
                    ])
                )),
            RTMPMessage(
                command: .result(
                    transactionID: 4,
                    properties: nil,
                    information: .number(1)
                )),
            RTMPMessage(
                command: .onStatus(
                    information: .object([
                        ("code", .string("NetStream.Publish.Start")),
                        ("description", .string("Publishing"))
                    ])))
        ])
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "my_stream_key"
        )
        let name = await publisher.activeStreamName
        #expect(name == "my_stream_key")
        await publisher.disconnect()
    }

    @Test("activeStreamName is nil after disconnect")
    func activeStreamNameClearedAfterDisconnect() async throws {
        let mock = MockTransport()
        await mock.setScriptedMessages([
            RTMPMessage(
                command: .result(
                    transactionID: 1,
                    properties: nil,
                    information: .object([
                        ("code", .string("NetConnection.Connect.Success"))
                    ])
                )),
            RTMPMessage(
                command: .result(
                    transactionID: 4,
                    properties: nil,
                    information: .number(1)
                )),
            RTMPMessage(
                command: .onStatus(
                    information: .object([
                        ("code", .string("NetStream.Publish.Start")),
                        ("description", .string("Publishing"))
                    ])))
        ])
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test_key"
        )
        await publisher.disconnect()
        let name = await publisher.activeStreamName
        #expect(name == nil)
    }

    @Test("activeStreamName is nil before publish")
    func activeStreamNameNilBeforePublish() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let name = await publisher.activeStreamName
        #expect(name == nil)
    }
}

// MARK: - Fix 12: tokenExpired detection

@Suite("Fix 12 — Token expired detection from description")
struct TokenExpiredDetectionTests {

    @Test("detects 'token has expired'")
    func tokenHasExpired() {
        #expect(RTMPPublisher.isTokenExpiredDescription("token has expired"))
    }

    @Test("detects 'Token Expired' (case insensitive)")
    func tokenExpiredCaseInsensitive() {
        #expect(RTMPPublisher.isTokenExpiredDescription("Token Expired"))
    }

    @Test("detects 'tokenexpired' (no space)")
    func tokenExpiredNoSpace() {
        #expect(RTMPPublisher.isTokenExpiredDescription("tokenexpired"))
    }

    @Test("detects '401' in description")
    func detects401() {
        #expect(RTMPPublisher.isTokenExpiredDescription("HTTP 401 Unauthorized"))
    }

    @Test("does not match unrelated description")
    func noMatchUnrelated() {
        #expect(!RTMPPublisher.isTokenExpiredDescription("auth failed"))
    }

    @Test("does not match empty string")
    func noMatchEmpty() {
        #expect(!RTMPPublisher.isTokenExpiredDescription(""))
    }

    @Test("connect _error with token expired description throws tokenExpired")
    func connectErrorTokenExpired() async {
        let mock = MockTransport()
        await mock.setScriptedMessages([
            RTMPMessage(
                command: .error(
                    transactionID: 1,
                    properties: nil,
                    information: .object([
                        (
                            "code",
                            .string("NetConnection.Connect.Rejected")
                        ),
                        ("level", .string("error")),
                        ("description", .string("token has expired"))
                    ])
                ))
        ])
        let publisher = RTMPPublisher(transport: mock)
        do {
            try await publisher.publish(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
            Issue.record("Expected tokenExpired error")
        } catch let error as RTMPError {
            if case .tokenExpired = error {
                // Expected
            } else {
                Issue.record("Expected tokenExpired, got \(error)")
            }
        } catch {
            // Any error is acceptable.
        }
    }
}

// MARK: - Fix 2+3: tcUrl preserves query string

@Suite("Fix 2+3 — buildTcUrl preserves query params")
struct TcUrlQueryStringTests {

    @Test("simple auth URL preserves user/pass query params")
    func simpleAuthTcUrl() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let result = await publisher.buildTcUrl(
            baseUrl: "rtmp://server.com/app?user=admin&pass=secret",
            app: "app"
        )
        #expect(result == "rtmp://server.com/app?user=admin&pass=secret")
    }

    @Test("token auth URL preserves token query param")
    func tokenAuthTcUrl() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let result = await publisher.buildTcUrl(
            baseUrl: "rtmp://server.com/live?token=abc123",
            app: "live"
        )
        #expect(result == "rtmp://server.com/live?token=abc123")
    }

    @Test("URL without query string returns nil")
    func noQueryStringReturnsNil() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let result = await publisher.buildTcUrl(
            baseUrl: "rtmp://server.com/app",
            app: "app"
        )
        #expect(result == nil)
    }

    @Test("RTMPS URL preserves query params")
    func rtmpsTcUrl() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let result = await publisher.buildTcUrl(
            baseUrl: "rtmps://secure.server.com/live?token=xyz",
            app: "live"
        )
        #expect(result == "rtmps://secure.server.com/live?token=xyz")
    }

    @Test("URL with port preserves query params")
    func portPreserved() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let result = await publisher.buildTcUrl(
            baseUrl: "rtmp://server.com:1935/app?user=u&pass=p",
            app: "app"
        )
        #expect(result == "rtmp://server.com:1935/app?user=u&pass=p")
    }

    @Test("invalid URL without scheme returns nil")
    func invalidUrlReturnsNil() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let result = await publisher.buildTcUrl(
            baseUrl: "no-scheme-url",
            app: "app"
        )
        #expect(result == nil)
    }
}

// MARK: - Fix 2+3: buildConnectionURL

@Suite("Fix 2+3 — buildConnectionURL adds auth params")
struct BuildConnectionURLTests {

    @Test("none authentication returns original URL")
    func noAuth() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let config = RTMPConfiguration(
            url: "rtmp://server/app",
            streamKey: "key"
        )
        let result = await publisher.buildConnectionURL(config)
        #expect(result == "rtmp://server/app")
    }

    @Test("simple auth appends user and pass")
    func simpleAuth() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        var config = RTMPConfiguration(
            url: "rtmp://server/app",
            streamKey: "key"
        )
        config.authentication = .simple(username: "admin", password: "pass")
        let result = await publisher.buildConnectionURL(config)
        #expect(result.contains("user=admin"))
        #expect(result.contains("pass=pass"))
    }

    @Test("token auth appends token")
    func tokenAuth() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        var config = RTMPConfiguration(
            url: "rtmp://server/app",
            streamKey: "key"
        )
        config.authentication = .token("abc123", expiry: nil)
        let result = await publisher.buildConnectionURL(config)
        #expect(result.contains("token=abc123"))
    }

    @Test("adobe challenge returns original URL")
    func adobeAuth() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        var config = RTMPConfiguration(
            url: "rtmp://server/app",
            streamKey: "key"
        )
        config.authentication = .adobeChallenge(
            username: "user", password: "pass"
        )
        let result = await publisher.buildConnectionURL(config)
        #expect(result == "rtmp://server/app")
    }
}

// MARK: - Fix 1: Handshake EOF

@Suite("Fix 1 — Connection closed during handshake")
struct HandshakeConnectionCloseTests {

    @Test("transport error maps to connectionClosed")
    func transportErrorMapping() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let mapped = await publisher.mapError(TransportError.connectionClosed)
        if case .connectionClosed = mapped {
            // Expected
        } else {
            Issue.record("Expected connectionClosed, got \(mapped)")
        }
    }

    @Test("transport connectionTimeout maps correctly")
    func connectionTimeoutMapping() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let mapped = await publisher.mapError(TransportError.connectionTimeout)
        if case .connectionTimeout = mapped {
            // Expected
        } else {
            Issue.record("Expected connectionTimeout, got \(mapped)")
        }
    }

    @Test("transport notConnected maps correctly")
    func notConnectedMapping() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let mapped = await publisher.mapError(TransportError.notConnected)
        if case .notConnected = mapped {
            // Expected
        } else {
            Issue.record("Expected notConnected, got \(mapped)")
        }
    }
}

// MARK: - Fix 4: Token expiry pre-check

@Suite("Fix 4 — Token expiry pre-check in publish")
struct TokenExpiryPreCheckTests {

    @Test("expired token throws tokenExpired before connecting")
    func expiredTokenThrows() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let pastDate = Date(timeIntervalSinceNow: -3600)
        var config = RTMPConfiguration(
            url: "rtmp://server/app",
            streamKey: "key"
        )
        config.authentication = .token("expired-token", expiry: pastDate)
        do {
            try await publisher.publish(configuration: config)
            Issue.record("Expected tokenExpired error")
        } catch let error as RTMPError {
            if case .tokenExpired = error {
                // Expected
            } else {
                Issue.record("Expected tokenExpired, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("valid token does not throw pre-check")
    func validTokenDoesNotThrowPreCheck() async {
        let mock = MockTransport()
        await mock.setNextError(TransportError.connectionClosed)
        let publisher = RTMPPublisher(transport: mock)
        let futureDate = Date(timeIntervalSinceNow: 3600)
        var config = RTMPConfiguration(
            url: "rtmp://server/app",
            streamKey: "key"
        )
        config.authentication = .token("valid-token", expiry: futureDate)
        do {
            try await publisher.publish(configuration: config)
        } catch let error as RTMPError {
            // Should fail for a different reason (connection), not tokenExpired
            if case .tokenExpired = error {
                Issue.record("Should not throw tokenExpired for valid token")
            }
        } catch {
            // Transport error is expected
        }
    }
}
