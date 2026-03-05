// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Builds token-based authentication URLs.
///
/// Appends a `token` query parameter to the connection URL, with optional
/// expiry checking.
public struct TokenAuth: Sendable {

    /// Append `?token=<token>` to the given URL.
    ///
    /// If the URL already has query parameters, appends with `&`.
    ///
    /// - Parameters:
    ///   - base: The base RTMP URL.
    ///   - token: The authentication token.
    /// - Returns: The URL with the token query parameter appended.
    public static func buildURL(base: String, token: String) -> String {
        let separator = base.contains("?") ? "&" : "?"
        return "\(base)\(separator)token=\(token)"
    }

    /// Returns `true` if the token is expired (expiry date is in the past).
    ///
    /// Returns `false` if expiry is `nil` (no expiry set).
    ///
    /// - Parameter expiry: The token expiration date, or `nil`.
    /// - Returns: Whether the token has expired.
    public static func isExpired(expiry: Date?) -> Bool {
        guard let expiry else { return false }
        return expiry < Date()
    }
}
