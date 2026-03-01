// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("TransportConfiguration")
struct TransportConfigurationTests {

    // MARK: - Default Configuration

    @Test("Default connectTimeout is 15")
    func defaultConnectTimeout() {
        let config = TransportConfiguration.default
        #expect(config.connectTimeout == 15)
    }

    @Test("Default receiveBufferSize is 64KB")
    func defaultReceiveBufferSize() {
        let config = TransportConfiguration.default
        #expect(config.receiveBufferSize == 64 * 1024)
    }

    @Test("Default sendBufferSize is 64KB")
    func defaultSendBufferSize() {
        let config = TransportConfiguration.default
        #expect(config.sendBufferSize == 64 * 1024)
    }

    @Test("Default tcpNoDelay is true")
    func defaultTcpNoDelay() {
        let config = TransportConfiguration.default
        #expect(config.tcpNoDelay)
    }

    @Test("Default TLS minimum version is TLS 1.2")
    func defaultTlsVersion() {
        let config = TransportConfiguration.default
        #expect(config.tlsMinimumVersion == .tlsv12)
    }

    // MARK: - Low Latency Configuration

    @Test("Low latency connectTimeout is 10")
    func lowLatencyConnectTimeout() {
        let config = TransportConfiguration.lowLatency
        #expect(config.connectTimeout == 10)
    }

    @Test("Low latency receiveBufferSize is 32KB")
    func lowLatencyReceiveBufferSize() {
        let config = TransportConfiguration.lowLatency
        #expect(config.receiveBufferSize == 32 * 1024)
    }

    @Test("Low latency sendBufferSize is 32KB")
    func lowLatencySendBufferSize() {
        let config = TransportConfiguration.lowLatency
        #expect(config.sendBufferSize == 32 * 1024)
    }

    @Test("Low latency tcpNoDelay is true")
    func lowLatencyTcpNoDelay() {
        let config = TransportConfiguration.lowLatency
        #expect(config.tcpNoDelay)
    }

    // MARK: - Custom Init

    @Test("Custom init sets all parameters")
    func customInit() {
        let config = TransportConfiguration(
            connectTimeout: 30,
            receiveBufferSize: 128 * 1024,
            sendBufferSize: 256 * 1024,
            tcpNoDelay: false,
            tlsMinimumVersion: .tlsv13
        )
        #expect(config.connectTimeout == 30)
        #expect(config.receiveBufferSize == 128 * 1024)
        #expect(config.sendBufferSize == 256 * 1024)
        #expect(!config.tcpNoDelay)
        #expect(config.tlsMinimumVersion == .tlsv13)
    }

    // MARK: - TLS Version

    @Test("TLSVersion has two cases")
    func tlsVersionCases() {
        let v12 = TLSVersion.tlsv12
        let v13 = TLSVersion.tlsv13
        #expect(v12 != v13)
    }

    // MARK: - Equatable

    @Test("Default and lowLatency are not equal")
    func defaultNotEqualLowLatency() {
        #expect(TransportConfiguration.default != TransportConfiguration.lowLatency)
    }

    @Test("Same configurations are equal")
    func sameConfigEqual() {
        let a = TransportConfiguration(connectTimeout: 5)
        let b = TransportConfiguration(connectTimeout: 5)
        #expect(a == b)
    }
}
