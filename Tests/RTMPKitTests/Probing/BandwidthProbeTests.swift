// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("BandwidthProbe")
struct BandwidthProbeTests {

    @Test("probe returns a ProbeResult")
    func probeReturnsResult() async throws {
        let probe = BandwidthProbe(
            configuration: .init(
                duration: 0.3, burstInterval: 0.05, warmupBursts: 1
            ),
            transportFactory: { _ in MockTransport() }
        )
        let result = try await probe.probe(
            url: "rtmp://localhost/app"
        )
        #expect(result.estimatedBandwidth > 0)
    }

    @Test("estimatedBandwidth is positive after probe")
    func bandwidthPositive() async throws {
        let probe = makeFastProbe()
        let result = try await probe.probe(
            url: "rtmp://server/app"
        )
        #expect(result.estimatedBandwidth > 0)
    }

    @Test("burstsSent >= warmupBursts")
    func burstsCount() async throws {
        let warmup = 2
        let probe = BandwidthProbe(
            configuration: .init(
                duration: 0.5, burstInterval: 0.05, warmupBursts: warmup
            ),
            transportFactory: { _ in MockTransport() }
        )
        let result = try await probe.probe(
            url: "rtmp://server/app"
        )
        #expect(result.burstsSent >= warmup)
    }

    @Test("probeDuration is approximately configured duration")
    func durationApproximate() async throws {
        let probe = BandwidthProbe(
            configuration: .init(
                duration: 0.3, burstInterval: 0.05, warmupBursts: 1
            ),
            transportFactory: { _ in MockTransport() }
        )
        let result = try await probe.probe(
            url: "rtmp://server/app"
        )
        // Should be within 2x of configured duration
        #expect(result.probeDuration >= 0.1)
        #expect(result.probeDuration < 1.0)
    }

    @Test("signalQuality is between 0 and 1")
    func signalQualityBounds() async throws {
        let probe = makeFastProbe()
        let result = try await probe.probe(
            url: "rtmp://server/app"
        )
        #expect(result.signalQuality >= 0.0)
        #expect(result.signalQuality <= 1.0)
    }

    @Test("Cancel mid-probe throws CancellationError")
    func cancelProbe() async throws {
        let probe = BandwidthProbe(
            configuration: .init(
                duration: 10.0, burstInterval: 0.01, warmupBursts: 0
            ),
            transportFactory: { _ in MockTransport() }
        )

        // Cancel after a short delay
        Task {
            try await Task.sleep(nanoseconds: 50_000_000)
            await probe.cancel()
        }

        do {
            _ = try await probe.probe(url: "rtmp://server/app")
            Issue.record("Expected CancellationError")
        } catch is CancellationError {
            // Expected
        }
    }

    @Test("Connection failure throws error")
    func connectionFailure() async throws {
        let probe = BandwidthProbe(
            configuration: .init(
                duration: 0.3, burstInterval: 0.05, warmupBursts: 0
            ),
            transportFactory: { _ in FailingTransportMock() }
        )

        do {
            _ = try await probe.probe(url: "rtmp://bad.host/app")
            Issue.record("Expected connection error")
        } catch {
            // Expected — connection should fail
        }
    }

    @Test("RTMPS URL uses TLS")
    func rtmpsUsesTLS() async throws {
        let mock = MockTransport()
        let probe = BandwidthProbe(
            configuration: .init(
                duration: 0.2, burstInterval: 0.05, warmupBursts: 0
            ),
            transportFactory: { _ in mock }
        )

        _ = try await probe.probe(
            url: "rtmps://secure.server.com:443/app"
        )
        let usedTLS = await mock.connectUseTLS
        #expect(usedTLS == true)
    }

    // MARK: - Helpers

    private func makeFastProbe() -> BandwidthProbe {
        BandwidthProbe(
            configuration: .init(
                duration: 0.2, burstInterval: 0.05, warmupBursts: 1
            ),
            transportFactory: { _ in MockTransport() }
        )
    }
}

/// Mock transport that always fails on connect.
private actor FailingTransportMock: RTMPTransportProtocol {

    var isConnected: Bool { false }

    func connect(
        host: String, port: Int, useTLS: Bool
    ) async throws {
        throw TransportError.connectionTimeout
    }

    func send(_ bytes: [UInt8]) async throws {
        throw TransportError.notConnected
    }

    func receive() async throws -> RTMPMessage {
        throw TransportError.notConnected
    }

    func close() async throws {}
}
