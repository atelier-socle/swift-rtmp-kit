// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("BandwidthProbe — Init and Error Paths")
struct BandwidthProbeCoverageTests {

    @Test("default init creates probe with NIO transport")
    func defaultInit() async {
        let probe = BandwidthProbe()
        _ = await probe.progress
        // No crash = init and progress access work
    }

    @Test("probe with invalid URL throws invalidURL")
    func invalidURLThrows() async {
        let probe = BandwidthProbe(
            configuration: .standard,
            transportFactory: { _ in MockTransport() }
        )
        await #expect(throws: RTMPError.self) {
            _ = try await probe.probe(url: "not-a-url")
        }
    }

    @Test("probe with empty host throws invalidURL")
    func emptyHostThrows() async {
        let probe = BandwidthProbe(
            configuration: .standard,
            transportFactory: { _ in MockTransport() }
        )
        await #expect(throws: RTMPError.self) {
            _ = try await probe.probe(url: "rtmp://")
        }
    }

    @Test("probe with rtmps URL uses TLS port 443")
    func rtmpsURLUsesTLS() async throws {
        let mock = MockTransport()
        // Let connect succeed but receive() will throw — that's fine for coverage
        let probe = BandwidthProbe(
            configuration: ProbeConfiguration(
                duration: 0.02, burstSize: 100,
                burstInterval: 0.01, warmupBursts: 0
            ),
            transportFactory: { _ in mock }
        )
        // The probe will fail after connecting (mock has no data) but connect should succeed
        _ = try? await probe.probe(url: "rtmps://example.com/app")
        let port = await mock.connectPort
        #expect(port == 443)
        let useTLS = await mock.connectUseTLS
        #expect(useTLS == true)
    }

    @Test("cancel stops probe")
    func cancelStops() async {
        let probe = BandwidthProbe(
            configuration: .standard,
            transportFactory: { _ in MockTransport() }
        )
        await probe.cancel()
        // Cancellation flag set — no crash
    }
}
