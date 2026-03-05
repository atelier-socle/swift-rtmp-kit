// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("SimpleAuth — URL Building")
struct SimpleAuthTests {

    @Test("buildURL appends ?user=x&pass=y when no existing query params")
    func noExistingParams() {
        let url = SimpleAuth.buildURL(
            base: "rtmp://server/app",
            username: "user1", password: "pass1"
        )
        #expect(url == "rtmp://server/app?user=user1&pass=pass1")
    }

    @Test("buildURL appends &user=x&pass=y when query params already present")
    func existingParams() {
        let url = SimpleAuth.buildURL(
            base: "rtmp://server/app?existing=true",
            username: "user1", password: "pass1"
        )
        #expect(url == "rtmp://server/app?existing=true&user=user1&pass=pass1")
    }

    @Test("buildURL percent-encodes special characters")
    func specialCharacters() {
        let url = SimpleAuth.buildURL(
            base: "rtmp://server/app",
            username: "user@domain", password: "p&ss=w0rd"
        )
        #expect(url.contains("user=user%40domain"))
        #expect(url.contains("pass=p%26ss%3Dw0rd"))
    }

    @Test("buildURL with empty username produces valid URL")
    func emptyUsername() {
        let url = SimpleAuth.buildURL(
            base: "rtmp://server/app",
            username: "", password: "pass"
        )
        #expect(url == "rtmp://server/app?user=&pass=pass")
    }

    @Test("Result starts with the base URL")
    func startsWithBase() {
        let base = "rtmp://my.server.com:1935/live"
        let url = SimpleAuth.buildURL(
            base: base, username: "u", password: "p"
        )
        #expect(url.hasPrefix(base))
    }
}
