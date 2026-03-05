// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Bandwidth Probing

extension RTMPPublisher {

    /// Probe the server and return the bandwidth measurement result.
    ///
    /// Runs a ``BandwidthProbe`` against the given URL to measure
    /// available uplink bandwidth before publishing.
    ///
    /// - Parameters:
    ///   - url: The RTMP server URL to probe.
    ///   - probeConfig: Probe configuration (default: `.standard`).
    /// - Returns: The probe result with bandwidth and quality measurements.
    /// - Throws: If the connection or probe fails.
    public func probeAndSelect(
        url: String,
        probeConfig: ProbeConfiguration = .standard
    ) async throws -> ProbeResult {
        let probe = BandwidthProbe(configuration: probeConfig)
        return try await probe.probe(url: url)
    }
}

// MARK: - Quality Score Public API

extension RTMPPublisher {

    /// Current connection quality score. nil before first measurement.
    public var qualityScore: ConnectionQualityScore? {
        get async {
            await qualityMonitor?.currentScore
        }
    }

    /// Stream of quality scores updated every scoring interval.
    public var qualityScores: AsyncStream<ConnectionQualityScore> {
        get async {
            guard let monitor = qualityMonitor else {
                let (stream, continuation) = AsyncStream.makeStream(
                    of: ConnectionQualityScore.self
                )
                continuation.finish()
                return stream
            }
            return await monitor.scores
        }
    }

    /// Generate a quality report for the current reporting window.
    ///
    /// - Returns: A quality report, or nil if no scores have been recorded.
    public func qualityReport() async -> QualityReport? {
        await qualityMonitor?.generateReport()
    }
}

// MARK: - Quality Score Integration

extension RTMPPublisher {

    /// Starts the quality monitor and score forwarding task.
    /// Called alongside ABR monitor startup during the publish flow.
    internal func startQualityMonitorIfNeeded() {
        let monitor = ConnectionQualityMonitor(
            scoringInterval: 1.0,
            reportingWindow: 30.0
        )
        qualityMonitor = monitor

        Task {
            await monitor.setWarningHandler { [weak self] dimension, score in
                Task { [weak self] in
                    await self?.emitEvent(
                        .qualityWarning(dimension: dimension, score: score)
                    )
                }
            }
            await monitor.start()
        }

        qualityMonitorTask = Task { [weak self] in
            let stream = await monitor.scores
            for await score in stream {
                guard !Task.isCancelled else { return }
                await self?.emitEvent(.qualityScoreUpdated(score))
            }
        }
    }

    /// Forwards byte-sent signal to the quality monitor.
    internal func recordBytesForQuality(_ bytes: Int) async {
        await qualityMonitor?.recordBytesSent(
            bytes, targetBitrate: liveVideoBitrate
        )
        await qualityMonitor?.recordBitrateAchievement(
            actual: liveVideoBitrate,
            configured: currentConfiguration?.initialMetadata?.videoBitrate ?? liveVideoBitrate
        )
    }

    /// Forwards a frame drop to the quality monitor.
    internal func recordFrameDropForQuality() async {
        await qualityMonitor?.recordFrameDrop()
    }

    /// Forwards a sent frame to the quality monitor.
    internal func recordSentFrameForQuality() async {
        await qualityMonitor?.recordSentFrame()
    }

    /// Forwards an RTT signal to the quality monitor.
    internal func recordRTTForQuality(_ rtt: Double) async {
        await qualityMonitor?.recordRTT(rtt)
    }
}
