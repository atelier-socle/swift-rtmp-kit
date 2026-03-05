// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AuthCrypto — Hash Functions")
struct AuthCryptoTests {

    @Test("md5 of empty string matches known vector")
    func md5Empty() {
        #expect(AuthCrypto.md5("") == "d41d8cd98f00b204e9800998ecf8427e")
    }

    @Test("md5 of 'hello' matches known vector")
    func md5Hello() {
        #expect(AuthCrypto.md5("hello") == "5d41402abc4b2a76b9719d911017c592")
    }

    @Test("sha256 of empty string matches known vector")
    func sha256Empty() {
        #expect(
            AuthCrypto.sha256("")
                == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    @Test("sha256 of 'hello' matches known vector")
    func sha256Hello() {
        #expect(
            AuthCrypto.sha256("hello")
                == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }

    @Test("hmacSHA256 produces correct output")
    func hmacSHA256Known() {
        let result = AuthCrypto.hmacSHA256(data: "message", key: "secret")
        // Known HMAC-SHA256("message", "secret")
        #expect(result.count == 64)
        #expect(result.allSatisfy { "0123456789abcdef".contains($0) })
    }

    @Test("md5 output is always 32 lowercase hex characters")
    func md5Format() {
        let result = AuthCrypto.md5("test input 123")
        #expect(result.count == 32)
        #expect(result.allSatisfy { "0123456789abcdef".contains($0) })
    }

    @Test("sha256 output is always 64 lowercase hex characters")
    func sha256Format() {
        let result = AuthCrypto.sha256("test input 123")
        #expect(result.count == 64)
        #expect(result.allSatisfy { "0123456789abcdef".contains($0) })
    }

    @Test("Results are deterministic across multiple calls")
    func deterministic() {
        let r1 = AuthCrypto.md5("deterministic")
        let r2 = AuthCrypto.md5("deterministic")
        #expect(r1 == r2)

        let s1 = AuthCrypto.sha256("deterministic")
        let s2 = AuthCrypto.sha256("deterministic")
        #expect(s1 == s2)
    }
}
