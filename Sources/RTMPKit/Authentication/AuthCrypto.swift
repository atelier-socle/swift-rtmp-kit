// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

#if canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif


/// Cross-platform cryptographic helpers for RTMP authentication.
///
/// Uses CryptoKit on Apple platforms, swift-crypto on Linux.
enum AuthCrypto {

    /// Returns the MD5 hash of the input string as a lowercase hex string.
    static func md5(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Returns the SHA256 hash of the input string as a lowercase hex string.
    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Returns the HMAC-SHA256 of `data` keyed with `key`, as a lowercase hex string.
    static func hmacSHA256(data: String, key: String) -> String {
        let keyData = SymmetricKey(data: Data(key.utf8))
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data(data.utf8), using: keyData
        )
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }
}
