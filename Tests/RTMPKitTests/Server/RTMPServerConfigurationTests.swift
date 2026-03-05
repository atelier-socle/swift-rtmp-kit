// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPServerConfiguration")
struct RTMPServerConfigurationTests {

    @Test("default port is 1935")
    func defaultPort() {
        let config = RTMPServerConfiguration()
        #expect(config.port == 1935)
    }

    @Test("default host is 0.0.0.0")
    func defaultHost() {
        let config = RTMPServerConfiguration()
        #expect(config.host == "0.0.0.0")
    }

    @Test("default maxSessions is 10")
    func defaultMaxSessions() {
        let config = RTMPServerConfiguration()
        #expect(config.maxSessions == 10)
    }

    @Test("default chunkSize is 4096")
    func defaultChunkSize() {
        let config = RTMPServerConfiguration()
        #expect(config.chunkSize == 4096)
    }

    @Test(".localhost preset: host is 127.0.0.1")
    func localhostPreset() {
        let config = RTMPServerConfiguration.localhost
        #expect(config.host == "127.0.0.1")
        #expect(config.maxSessions == 5)
    }

    @Test(".production preset: maxSessions >= 50")
    func productionPreset() {
        let config = RTMPServerConfiguration.production
        #expect(config.maxSessions >= 50)
        #expect(config.host == "0.0.0.0")
    }
}
