// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AdobeChallengeAuth — Challenge Parsing")
struct AdobeChallengeParsingTests {

    @Test("parseChallenge with valid Adobe description returns correct parameters")
    func validDescription() {
        let description =
            "[ AccessManager.Reject ] : [ code=403 need auth; authmod=adobe ] : "
            + "/live : ?reason=needauth&user=&salt=6MnrBnKW&challenge=7C5OrwQg&opaque=vbi2V"
        let params = AdobeChallengeAuth.parseChallenge(from: description)
        #expect(params?.salt == "6MnrBnKW")
        #expect(params?.challenge == "7C5OrwQg")
        #expect(params?.opaque == "vbi2V")
    }

    @Test("parseChallenge with description missing salt returns nil")
    func missingSalt() {
        let description =
            "[ AccessManager.Reject ] : [ authmod=adobe ] : "
            + "?reason=needauth&challenge=abc&opaque=xyz"
        #expect(AdobeChallengeAuth.parseChallenge(from: description) == nil)
    }

    @Test("parseChallenge with empty opaque returns empty string")
    func emptyOpaque() {
        let description =
            "[ AccessManager.Reject ] : [ authmod=adobe ] : "
            + "?reason=needauth&salt=abc&challenge=def&opaque="
        let params = AdobeChallengeAuth.parseChallenge(from: description)
        #expect(params != nil)
        #expect(params?.opaque == "")
    }

    @Test("parseChallenge with non-Adobe description returns nil")
    func nonAdobeDescription() {
        let description = "NetConnection.Connect.Rejected"
        #expect(AdobeChallengeAuth.parseChallenge(from: description) == nil)
    }

    @Test("parseChallenge with missing challenge returns nil")
    func missingChallenge() {
        let description =
            "[ authmod=adobe ] : ?reason=needauth&salt=abc&opaque=xyz"
        #expect(AdobeChallengeAuth.parseChallenge(from: description) == nil)
    }
}

@Suite("AdobeChallengeAuth — Response Computation")
struct AdobeChallengeResponseTests {

    @Test("computeResponse contains authmod=adobe")
    func containsAuthmod() {
        let params = AdobeChallengeAuth.ChallengeParameters(
            salt: "salt", challenge: "chal", opaque: "opq"
        )
        let response = AdobeChallengeAuth.computeResponse(
            username: "user", password: "pass",
            challenge: params, clientChallenge: "a1b2c3d4"
        )
        #expect(response.contains("authmod=adobe"))
    }

    @Test("computeResponse contains user=<username>")
    func containsUser() {
        let params = AdobeChallengeAuth.ChallengeParameters(
            salt: "salt", challenge: "chal", opaque: "opq"
        )
        let response = AdobeChallengeAuth.computeResponse(
            username: "broadcaster", password: "pass",
            challenge: params, clientChallenge: "a1b2c3d4"
        )
        #expect(response.contains("user=broadcaster"))
    }

    @Test("computeResponse contains challenge=<clientChallenge>")
    func containsClientChallenge() {
        let params = AdobeChallengeAuth.ChallengeParameters(
            salt: "salt", challenge: "chal", opaque: "opq"
        )
        let response = AdobeChallengeAuth.computeResponse(
            username: "user", password: "pass",
            challenge: params, clientChallenge: "deadbeef"
        )
        #expect(response.contains("challenge=deadbeef"))
    }

    @Test("computeResponse contains response= with 32-char hex string (MD5)")
    func responseIs32Hex() {
        let params = AdobeChallengeAuth.ChallengeParameters(
            salt: "salt", challenge: "chal", opaque: "opq"
        )
        let response = AdobeChallengeAuth.computeResponse(
            username: "user", password: "pass",
            challenge: params, clientChallenge: "a1b2c3d4"
        )
        // Extract the response= value
        let parts = response.split(separator: "&")
        let responsePart = parts.first { $0.hasPrefix("response=") }
        let responseValue = responsePart.map { String($0.dropFirst("response=".count)) }
        #expect(responseValue?.count == 32)
        #expect(responseValue?.allSatisfy { "0123456789abcdef".contains($0) } == true)
    }

    @Test("computeResponse is deterministic for same inputs")
    func deterministic() {
        let params = AdobeChallengeAuth.ChallengeParameters(
            salt: "s", challenge: "c", opaque: "o"
        )
        let r1 = AdobeChallengeAuth.computeResponse(
            username: "u", password: "p",
            challenge: params, clientChallenge: "11223344"
        )
        let r2 = AdobeChallengeAuth.computeResponse(
            username: "u", password: "p",
            challenge: params, clientChallenge: "11223344"
        )
        #expect(r1 == r2)
    }

    @Test("computeResponse differs for different passwords")
    func differentPasswords() {
        let params = AdobeChallengeAuth.ChallengeParameters(
            salt: "s", challenge: "c", opaque: "o"
        )
        let r1 = AdobeChallengeAuth.computeResponse(
            username: "u", password: "p1",
            challenge: params, clientChallenge: "11223344"
        )
        let r2 = AdobeChallengeAuth.computeResponse(
            username: "u", password: "p2",
            challenge: params, clientChallenge: "11223344"
        )
        #expect(r1 != r2)
    }

    @Test("generateClientChallenge returns an 8-character string")
    func challengeLength() {
        let challenge = AdobeChallengeAuth.generateClientChallenge()
        #expect(challenge.count == 8)
    }

    @Test("generateClientChallenge returns only hex characters")
    func challengeHexOnly() {
        let challenge = AdobeChallengeAuth.generateClientChallenge()
        #expect(challenge.allSatisfy { "0123456789abcdef".contains($0) })
    }
}
