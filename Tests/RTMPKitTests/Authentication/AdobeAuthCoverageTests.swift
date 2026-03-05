// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AdobeChallengeAuth — Percent Encoding")
struct AdobeAuthPercentEncodingTests {

    @Test("computeResponse percent-encodes special characters in username")
    func percentEncodesSpecialChars() {
        let params = AdobeChallengeAuth.ChallengeParameters(
            salt: "abc", challenge: "xyz", opaque: "123"
        )
        let response = AdobeChallengeAuth.computeResponse(
            username: "user@domain.com",
            password: "pass",
            challenge: params,
            clientChallenge: "cli"
        )
        // '@' is not unreserved so should be percent-encoded
        #expect(response.contains("%40"))
    }
}
