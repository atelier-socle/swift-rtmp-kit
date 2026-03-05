// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Measures available uplink bandwidth by sending synthetic data bursts
/// to the target RTMP server before publishing begins.
///
/// The probe opens a TCP connection, sends the RTMP C0+C1 handshake,
/// then sends synthetic data bursts to measure throughput and RTT.
///
/// ## Usage
/// ```swift
/// let probe = BandwidthProbe(configuration: .standard)
/// let result = try await probe.probe(url: "rtmp://server/app")
/// print(result.summary)
/// ```
public actor BandwidthProbe {

    private let configuration: ProbeConfiguration
    private let transportFactory: @Sendable (String) -> any RTMPTransportProtocol
    private var cancelled = false
    private let progressContinuation: AsyncStream<Double>.Continuation
    private let progressStream: AsyncStream<Double>

    /// Creates a probe with the default NIO transport.
    ///
    /// - Parameter configuration: Probe configuration (default: `.standard`).
    public init(configuration: ProbeConfiguration = .standard) {
        self.configuration = configuration
        self.transportFactory = { _ in NIOTransport() }
        let (stream, continuation) = AsyncStream<Double>.makeStream()
        self.progressStream = stream
        self.progressContinuation = continuation
    }

    /// Creates a probe with a custom transport factory (for testing).
    ///
    /// - Parameters:
    ///   - configuration: Probe configuration.
    ///   - transportFactory: Closure that creates a transport for a given URL.
    public init(
        configuration: ProbeConfiguration,
        transportFactory: @escaping @Sendable (String) -> any RTMPTransportProtocol
    ) {
        self.configuration = configuration
        self.transportFactory = transportFactory
        let (stream, continuation) = AsyncStream<Double>.makeStream()
        self.progressStream = stream
        self.progressContinuation = continuation
    }

    /// Stream of progress updates during the probe (0.0–1.0).
    public var progress: AsyncStream<Double> {
        progressStream
    }

    /// Connect to the given RTMP server URL, send synthetic data bursts,
    /// measure throughput and RTT, then disconnect.
    ///
    /// - Parameter url: The RTMP/RTMPS server URL to probe.
    /// - Returns: The probe result.
    /// - Throws: If connection fails or the probe is cancelled.
    public func probe(url: String) async throws -> ProbeResult {
        cancelled = false

        let parsed = try parseURL(url)
        let transport = transportFactory(url)

        try await transport.connect(
            host: parsed.host, port: parsed.port, useTLS: parsed.useTLS
        )

        defer {
            Task { try? await transport.close() }
        }

        // Send C0+C1 handshake bytes as initial data
        let c0c1 = buildC0C1()
        try await transport.send(c0c1)

        // Run burst probing
        let result = try await runBursts(transport: transport)

        progressContinuation.yield(1.0)
        progressContinuation.finish()

        return result
    }

    /// Cancel an ongoing probe.
    public func cancel() {
        cancelled = true
        progressContinuation.finish()
    }
}

// MARK: - Private Implementation

extension BandwidthProbe {

    private func runBursts(
        transport: any RTMPTransportProtocol
    ) async throws -> ProbeResult {
        let burstData = [UInt8](repeating: 0xAA, count: configuration.burstSize)
        let startTime = ContinuousClock.now
        let endTime = startTime + .milliseconds(Int(configuration.duration * 1000))

        var rttSamples: [Double] = []
        var throughputSamples: [Double] = []
        var totalBurstsSent = 0
        var lostBursts = 0

        while ContinuousClock.now < endTime {
            guard !cancelled else {
                throw CancellationError()
            }

            let burstStart = ContinuousClock.now

            do {
                try await transport.send(burstData)
            } catch {
                lostBursts += 1
                totalBurstsSent += 1
                continue
            }

            let sendDuration = burstStart.duration(to: ContinuousClock.now)
            let sendMs =
                Double(sendDuration.components.attoseconds)
                / 1_000_000_000_000_000.0
            let sendSec = sendMs / 1000.0

            totalBurstsSent += 1

            // Measure RTT by checking time for send to complete
            // TCP send returning means the data was buffered/sent
            let rttMs = max(0.1, sendMs)

            // Only record measurement samples after warmup
            if totalBurstsSent > configuration.warmupBursts {
                rttSamples.append(rttMs)

                // Throughput: bytes sent / time taken
                if sendSec > 0 {
                    let bps = Double(configuration.burstSize * 8) / sendSec
                    throughputSamples.append(bps)
                }
            }

            // Report progress
            let elapsed = startTime.duration(to: ContinuousClock.now)
            let elapsedSec =
                Double(elapsed.components.attoseconds)
                / 1_000_000_000_000_000_000.0
            let pct = min(1.0, elapsedSec / configuration.duration)
            progressContinuation.yield(pct)

            // Wait between bursts
            let intervalNs = UInt64(configuration.burstInterval * 1_000_000_000)
            try await Task.sleep(nanoseconds: intervalNs)
        }

        let totalDuration = startTime.duration(to: ContinuousClock.now)
        let totalSec =
            Double(totalDuration.components.attoseconds)
            / 1_000_000_000_000_000_000.0

        return buildResult(
            rttSamples: rttSamples,
            throughputSamples: throughputSamples,
            totalBurstsSent: totalBurstsSent,
            lostBursts: lostBursts,
            probeDuration: totalSec
        )
    }

    private func buildResult(
        rttSamples: [Double],
        throughputSamples: [Double],
        totalBurstsSent: Int,
        lostBursts: Int,
        probeDuration: Double
    ) -> ProbeResult {
        let minRTT = rttSamples.min() ?? 0
        let maxRTT = rttSamples.max() ?? 0
        let avgRTT =
            rttSamples.isEmpty
            ? 0
            : rttSamples.reduce(0, +) / Double(rttSamples.count)

        // EWMA bandwidth estimation
        let bandwidth = ewmaBandwidth(throughputSamples)

        let totalMeasured = rttSamples.count + lostBursts
        let lossRate =
            totalMeasured > 0
            ? Double(lostBursts) / Double(totalMeasured)
            : 0

        let signalQuality = computeSignalQuality(
            minRTT: minRTT, maxRTT: maxRTT,
            avgRTT: avgRTT, lossRate: lossRate
        )

        return ProbeResult(
            estimatedBandwidth: Int(bandwidth),
            minRTT: minRTT,
            averageRTT: avgRTT,
            maxRTT: maxRTT,
            packetLossRate: lossRate,
            probeDuration: probeDuration,
            burstsSent: totalBurstsSent,
            signalQuality: signalQuality
        )
    }

    private func ewmaBandwidth(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }

        let alpha = 0.3
        var ewma = samples[0]
        for sample in samples.dropFirst() {
            ewma = alpha * sample + (1 - alpha) * ewma
        }
        return ewma
    }

    private func computeSignalQuality(
        minRTT: Double, maxRTT: Double,
        avgRTT: Double, lossRate: Double
    ) -> Double {
        let jitterScore: Double
        if avgRTT > 0 {
            jitterScore = 1.0 - min(1.0, (maxRTT - minRTT) / avgRTT)
        } else {
            jitterScore = 1.0
        }
        let lossScore = 1.0 - lossRate
        return max(0, min(1.0, (jitterScore * 0.6) + (lossScore * 0.4)))
    }

    private func buildC0C1() -> [UInt8] {
        // C0: version byte (3)
        // C1: 1536 bytes (timestamp + zero + random)
        var bytes = [UInt8](repeating: 0, count: 1537)
        bytes[0] = 3  // RTMP version
        // C1 timestamp at bytes 1-4 (zero is fine for probing)
        // Fill rest with pseudo-random data
        for i in 9..<1537 {
            bytes[i] = UInt8(i & 0xFF)
        }
        return bytes
    }

    private struct ParsedProbeURL {
        let host: String
        let port: Int
        let useTLS: Bool
    }

    private func parseURL(_ url: String) throws -> ParsedProbeURL {
        let useTLS: Bool
        let afterScheme: String

        if url.hasPrefix("rtmps://") {
            useTLS = true
            afterScheme = String(url.dropFirst("rtmps://".count))
        } else if url.hasPrefix("rtmp://") {
            useTLS = false
            afterScheme = String(url.dropFirst("rtmp://".count))
        } else {
            throw RTMPError.invalidURL(
                "Missing rtmp:// or rtmps:// scheme"
            )
        }

        guard !afterScheme.isEmpty else {
            throw RTMPError.invalidURL("Missing host")
        }

        // Extract host:port before any path
        let hostPort = afterScheme.split(
            separator: "/", maxSplits: 1,
            omittingEmptySubsequences: false
        )[0]

        let parts = hostPort.split(separator: ":", maxSplits: 1)
        let host = String(parts[0])
        let port: Int

        if parts.count > 1, let p = Int(parts[1]) {
            port = p
        } else {
            port = useTLS ? 443 : 1935
        }

        return ParsedProbeURL(host: host, port: port, useTLS: useTLS)
    }
}
