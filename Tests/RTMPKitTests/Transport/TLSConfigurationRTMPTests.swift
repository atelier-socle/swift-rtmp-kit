// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOSSL
import Testing

@testable import RTMPKit

@Suite("TLSConfiguration+RTMP")
struct TLSConfigurationRTMPTests {

    @Test("rtmps() creates config with TLS 1.2 minimum by default")
    func defaultMinimumVersion() {
        let config = TLSConfiguration.rtmps()
        #expect(config.minimumTLSVersion == .tlsv12)
    }

    @Test("rtmps(minimumVersion: .tlsv13) sets TLS 1.3 minimum")
    func tls13MinimumVersion() {
        let config = TLSConfiguration.rtmps(minimumVersion: .tlsv13)
        #expect(config.minimumTLSVersion == .tlsv13)
    }

    @Test("rtmps() uses full certificate verification")
    func fullCertificateVerification() {
        let config = TLSConfiguration.rtmps()
        #expect(config.certificateVerification == .fullVerification)
    }

    @Test("rtmps() config is usable — NIOSSLContext can be created")
    func configIsUsable() throws {
        let config = TLSConfiguration.rtmps()
        _ = try NIOSSLContext(configuration: config)
    }
}
