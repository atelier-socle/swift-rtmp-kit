// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

@Suite("Authentication Showcase — Configuration")
struct AuthShowcaseConfigTests {

    @Test("Default configuration has no authentication")
    func defaultAuth() {
        let config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
        #expect(config.authentication == .none)
    }

    @Test("Adobe challenge authentication for Wowza")
    func adobeAuth() {
        var config = RTMPConfiguration(
            url: "rtmp://wowza.server.com/live", streamKey: "myStream"
        )
        config.authentication = .adobeChallenge(
            username: "broadcaster", password: "s3cr3t"
        )
        #expect(
            config.authentication
                == .adobeChallenge(
                    username: "broadcaster", password: "s3cr3t"
                )
        )
    }

    @Test("Token authentication with expiry")
    func tokenAuth() {
        let expiry = Date().addingTimeInterval(3600)
        var config = RTMPConfiguration(
            url: "rtmp://cdn.example.com/live", streamKey: "stream123"
        )
        config.authentication = .token("eyJhbGciOiJ...", expiry: expiry)
        if case .token(let token, let exp) = config.authentication {
            #expect(token == "eyJhbGciOiJ...")
            #expect(exp == expiry)
        } else {
            Issue.record("Expected .token")
        }
    }
}

@Suite("Authentication Showcase — Adobe Challenge/Response")
struct AuthShowcaseAdobeTests {

    @Test("Parse server challenge from Wowza rejection")
    func parseWowzaChallenge() {
        let description =
            "[ AccessManager.Reject ] : [ code=403 need auth; authmod=adobe ] "
            + ": /live : ?reason=needauth&user=&salt=6MnrBnKW&challenge=7C5OrwQg&opaque=vbi2V"
        let params = AdobeChallengeAuth.parseChallenge(from: description)
        #expect(params?.salt == "6MnrBnKW")
        #expect(params?.challenge == "7C5OrwQg")
        #expect(params?.opaque == "vbi2V")
    }

    @Test("Compute and verify Adobe auth response")
    func computeResponse() {
        let params = AdobeChallengeAuth.ChallengeParameters(
            salt: "6MnrBnKW", challenge: "7C5OrwQg", opaque: "vbi2V"
        )
        let response = AdobeChallengeAuth.computeResponse(
            username: "broadcaster", password: "s3cr3t",
            challenge: params, clientChallenge: "a1b2c3d4"
        )
        #expect(response.contains("authmod=adobe"))
        #expect(response.contains("user=broadcaster"))
        #expect(response.contains("opaque=vbi2V"))
    }

    @Test("Non-Adobe rejection description is not parsed as challenge")
    func nonAdobeRejection() {
        let description = "NetConnection.Connect.Rejected"
        #expect(AdobeChallengeAuth.parseChallenge(from: description) == nil)
    }

    @Test("Client challenge is random and hex-only")
    func clientChallenge() {
        let c1 = AdobeChallengeAuth.generateClientChallenge()
        let c2 = AdobeChallengeAuth.generateClientChallenge()
        #expect(c1.count == 8)
        #expect(c2.count == 8)
        #expect(c1.allSatisfy { "0123456789abcdef".contains($0) })
        #expect(c2.allSatisfy { "0123456789abcdef".contains($0) })
    }
}

@Suite("Authentication Showcase — Publisher Integration")
struct AuthShowcasePublisherTests {

    @Test("Simple auth appends credentials to connection URL")
    func simpleAuthURL() async {
        let publisher = RTMPPublisher(transport: MockTransport())

        // Default: no auth, URL unchanged
        let defaultConfig = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
        let url = await publisher.buildConnectionURL(defaultConfig)
        #expect(url == "rtmp://server/app")

        // With simple auth
        var authConfig = defaultConfig
        authConfig.authentication = .simple(username: "user1", password: "pass1")
        let authURL = await publisher.buildConnectionURL(authConfig)
        #expect(authURL.contains("user=user1"))
        #expect(authURL.contains("pass=pass1"))
    }

    @Test("Expired token prevents connection")
    func expiredToken() async throws {
        var config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
        config.authentication = .token("abc123", expiry: Date.distantPast)
        let publisher = RTMPPublisher(transport: MockTransport())

        do {
            try await publisher.publish(configuration: config)
            Issue.record("Expected tokenExpired error")
        } catch let error as RTMPError {
            #expect(error == .tokenExpired)
        }
    }

    @Test("Token without expiry does not trigger expiry check")
    func tokenNoExpiry() {
        let config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
        var authConfig = config
        authConfig.authentication = .token("abc123")
        // isExpired should be false
        if case .token(_, let expiry) = authConfig.authentication {
            #expect(TokenAuth.isExpired(expiry: expiry) == false)
        }
    }

    @Test("RTMPError.authenticationFailed has correct description")
    func errorDescription() {
        let error = RTMPError.authenticationFailed("bad credentials")
        #expect(error.description == "Authentication failed: bad credentials")
    }

    @Test("RTMPError.tokenExpired has correct description")
    func tokenExpiredDescription() {
        let error = RTMPError.tokenExpired
        #expect(error.description == "Authentication token expired")
    }
}
