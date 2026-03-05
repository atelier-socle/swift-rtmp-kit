// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Authentication mechanism for RTMP connections.
///
/// Supports Adobe challenge/response, simple query-string credentials,
/// and token-based authentication with optional expiry.
public enum RTMPAuthentication: Sendable, Equatable {
    /// No authentication (default).
    case none

    /// Adobe RTMP challenge/response authentication (used by Wowza, AMS, some CDNs).
    ///
    /// The server sends a `NetConnection.Connect.Rejected` with a challenge string.
    /// The client computes a hash response and reconnects with the credentials.
    case adobeChallenge(username: String, password: String)

    /// Simple query-string authentication (Nginx-RTMP, SRS, and others).
    ///
    /// Appends `?user=<username>&pass=<password>` to the connection URL.
    case simple(username: String, password: String)

    /// Token-based authentication.
    ///
    /// Appends `?token=<token>` to the connection URL.
    /// Supports optional expiry — if expiry is set and the token is expired,
    /// the publisher emits a `.authenticationFailed` event before attempting connection.
    case token(String, expiry: Date? = nil)
}
