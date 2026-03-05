// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKit

@Suite("TokenAuth — URL Building and Expiry")
struct TokenAuthTests {

    @Test("buildURL appends ?token=<value>")
    func appendsToken() {
        let url = TokenAuth.buildURL(
            base: "rtmp://server/app", token: "abc123"
        )
        #expect(url == "rtmp://server/app?token=abc123")
    }

    @Test("buildURL with existing query params appends with &")
    func existingParams() {
        let url = TokenAuth.buildURL(
            base: "rtmp://server/app?key=val", token: "abc123"
        )
        #expect(url == "rtmp://server/app?key=val&token=abc123")
    }

    @Test("isExpired returns false for nil expiry")
    func nilExpiry() {
        #expect(TokenAuth.isExpired(expiry: nil) == false)
    }

    @Test("isExpired returns false for distantFuture")
    func distantFuture() {
        #expect(TokenAuth.isExpired(expiry: Date.distantFuture) == false)
    }

    @Test("isExpired returns true for distantPast")
    func distantPast() {
        #expect(TokenAuth.isExpired(expiry: Date.distantPast) == true)
    }

    @Test("isExpired returns false for date 1 hour in the future")
    func futureDate() {
        let future = Date().addingTimeInterval(3600)
        #expect(TokenAuth.isExpired(expiry: future) == false)
    }
}
