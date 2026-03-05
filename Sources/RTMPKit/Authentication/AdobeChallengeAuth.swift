// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Implements Adobe RTMP challenge/response authentication.
///
/// Used by Wowza Media Server and Adobe Media Server. The server sends
/// a `NetConnection.Connect.Rejected` with challenge parameters; the client
/// computes a hash response and reconnects with credentials.
public struct AdobeChallengeAuth: Sendable {

    /// Parse a `NetConnection.Connect.Rejected` description to extract challenge parameters.
    ///
    /// Returns `nil` if the description does not contain Adobe auth challenge parameters.
    ///
    /// - Parameter description: The rejection description string from the server.
    /// - Returns: Parsed challenge parameters, or `nil` if not an Adobe auth challenge.
    public static func parseChallenge(from description: String) -> ChallengeParameters? {
        guard description.contains("authmod=adobe") else { return nil }

        let params = parseQueryParameters(from: description)
        guard let salt = params["salt"], let challenge = params["challenge"] else {
            return nil
        }
        let opaque = params["opaque"] ?? ""
        return ChallengeParameters(salt: salt, challenge: challenge, opaque: opaque)
    }

    /// Compute the auth response URL query string for a given challenge.
    ///
    /// - Parameters:
    ///   - username: The username for authentication.
    ///   - password: The password for authentication.
    ///   - challenge: The challenge parameters from the server.
    ///   - clientChallenge: An 8-character hex client challenge string.
    /// - Returns: The full query string for reconnection.
    public static func computeResponse(
        username: String,
        password: String,
        challenge: ChallengeParameters,
        clientChallenge: String
    ) -> String {
        let hash1 = AuthCrypto.md5(username + challenge.salt + password)
        let hash2 = AuthCrypto.md5(hash1 + challenge.challenge + clientChallenge)

        var result = "authmod=adobe"
        result += "&user=\(percentEncode(username))"
        result += "&challenge=\(clientChallenge)"
        result += "&response=\(hash2)"
        if !challenge.opaque.isEmpty {
            result += "&opaque=\(percentEncode(challenge.opaque))"
        }
        return result
    }

    /// Generate a random 8-character hex client challenge string.
    ///
    /// - Returns: An 8-character string of lowercase hexadecimal characters.
    public static func generateClientChallenge() -> String {
        var bytes = [UInt8](repeating: 0, count: 4)
        for i in 0..<bytes.count {
            bytes[i] = UInt8.random(in: 0...255)
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private

    private static func parseQueryParameters(from description: String) -> [String: String] {
        // Find the query string portion after '?'
        guard let queryStart = description.firstIndex(of: "?") else { return [:] }
        let queryString = String(description[description.index(after: queryStart)...])

        var params: [String: String] = [:]
        let pairs = queryString.split(separator: "&")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                params[String(parts[0])] = String(parts[1])
            } else if parts.count == 1 {
                params[String(parts[0])] = ""
            }
        }
        return params
    }

    private static func percentEncode(_ string: String) -> String {
        var result = ""
        for char in string.utf8 {
            if isUnreserved(char) {
                result.append(Character(UnicodeScalar(char)))
            } else {
                result += String(format: "%%%02X", char)
            }
        }
        return result
    }

    private static func isUnreserved(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x2E, 0x5F, 0x7E:
            return true
        default:
            return false
        }
    }
}

extension AdobeChallengeAuth {

    /// Parameters extracted from a server challenge description.
    public struct ChallengeParameters: Sendable, Equatable {
        /// The salt value from the server challenge.
        public let salt: String
        /// The challenge value from the server challenge.
        public let challenge: String
        /// The opaque value from the server challenge (may be empty).
        public let opaque: String

        /// Creates challenge parameters.
        ///
        /// - Parameters:
        ///   - salt: The salt value.
        ///   - challenge: The challenge value.
        ///   - opaque: The opaque value.
        public init(salt: String, challenge: String, opaque: String) {
            self.salt = salt
            self.challenge = challenge
            self.opaque = opaque
        }
    }
}
