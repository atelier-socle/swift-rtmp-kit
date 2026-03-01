// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOSSL

extension TLSConfiguration {
    /// Create a TLS configuration suitable for RTMPS connections.
    ///
    /// Configures TLS with:
    /// - SNI (Server Name Indication) — required by platforms like YouTube
    /// - System trust store for certificate verification
    /// - Minimum TLS version as specified
    /// - No ALPN (not needed for RTMP, unlike HTTP/2)
    ///
    /// - Parameters:
    ///   - minimumVersion: Minimum TLS version (default: TLS 1.2).
    /// - Returns: A configured TLSConfiguration for RTMPS.
    public static func rtmps(
        minimumVersion: TLSVersion = .tlsv12
    ) -> TLSConfiguration {
        var config = TLSConfiguration.makeClientConfiguration()
        switch minimumVersion {
        case .tlsv12:
            config.minimumTLSVersion = .tlsv12
        case .tlsv13:
            config.minimumTLSVersion = .tlsv13
        }
        config.certificateVerification = .fullVerification
        return config
    }
}
