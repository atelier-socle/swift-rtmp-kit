// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Builds query-string authentication URLs for Nginx-RTMP, SRS, and similar servers.
///
/// Appends `user` and `pass` query parameters to the connection URL.
public struct SimpleAuth: Sendable {

    /// Append `?user=<username>&pass=<password>` to the given URL.
    ///
    /// If the URL already has query parameters, appends with `&`.
    /// Special characters in username and password are percent-encoded.
    ///
    /// - Parameters:
    ///   - base: The base RTMP URL.
    ///   - username: The username.
    ///   - password: The password.
    /// - Returns: The URL with authentication query parameters appended.
    public static func buildURL(base: String, username: String, password: String) -> String {
        let separator = base.contains("?") ? "&" : "?"
        let encodedUser = percentEncode(username)
        let encodedPass = percentEncode(password)
        return "\(base)\(separator)user=\(encodedUser)&pass=\(encodedPass)"
    }

    // MARK: - Private

    private static func percentEncode(_ string: String) -> String {
        var result = ""
        for byte in string.utf8 {
            if isUnreserved(byte) {
                result.append(Character(UnicodeScalar(byte)))
            } else {
                result += String(format: "%%%02X", byte)
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
