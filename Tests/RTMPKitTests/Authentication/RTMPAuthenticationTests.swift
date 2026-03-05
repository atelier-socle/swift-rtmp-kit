// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

@Suite("RTMPAuthentication — Enum")
struct RTMPAuthenticationTests {

    @Test("none case has no credentials")
    func noneCase() {
        let auth = RTMPAuthentication.none
        if case .none = auth {
            // OK
        } else {
            Issue.record("Expected .none")
        }
    }

    @Test("adobeChallenge stores username and password")
    func adobeChallenge() {
        let auth = RTMPAuthentication.adobeChallenge(
            username: "admin", password: "secret"
        )
        if case .adobeChallenge(let user, let pass) = auth {
            #expect(user == "admin")
            #expect(pass == "secret")
        } else {
            Issue.record("Expected .adobeChallenge")
        }
    }

    @Test("simple stores username and password")
    func simpleAuth() {
        let auth = RTMPAuthentication.simple(
            username: "user1", password: "pass1"
        )
        if case .simple(let user, let pass) = auth {
            #expect(user == "user1")
            #expect(pass == "pass1")
        } else {
            Issue.record("Expected .simple")
        }
    }

    @Test("token stores token string")
    func tokenAuth() {
        let auth = RTMPAuthentication.token("abc123")
        if case .token(let token, let expiry) = auth {
            #expect(token == "abc123")
            #expect(expiry == nil)
        } else {
            Issue.record("Expected .token")
        }
    }

    @Test("token with expiry stores the date")
    func tokenWithExpiry() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let auth = RTMPAuthentication.token("xyz", expiry: date)
        if case .token(let token, let expiry) = auth {
            #expect(token == "xyz")
            #expect(expiry == date)
        } else {
            Issue.record("Expected .token")
        }
    }

    @Test("Equatable: same values are equal, different values are not")
    func equatable() {
        #expect(RTMPAuthentication.none == RTMPAuthentication.none)
        #expect(
            RTMPAuthentication.simple(username: "a", password: "b")
                == RTMPAuthentication.simple(username: "a", password: "b")
        )
        #expect(
            RTMPAuthentication.simple(username: "a", password: "b")
                != RTMPAuthentication.simple(username: "a", password: "c")
        )
        #expect(
            RTMPAuthentication.adobeChallenge(username: "a", password: "b")
                != RTMPAuthentication.simple(username: "a", password: "b")
        )
    }
}
