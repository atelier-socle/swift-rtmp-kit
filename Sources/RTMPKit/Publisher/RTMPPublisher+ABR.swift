// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Adaptive Bitrate Integration

extension RTMPPublisher {

    /// Starts the ABR monitor and recommendation forwarding task if the
    /// current configuration has an active adaptive bitrate policy.
    internal func startABRMonitorIfNeeded() async {
        guard let config = currentConfiguration,
            config.adaptiveBitrate != .disabled
        else {
            return
        }

        let monitor = NetworkConditionMonitor(
            policy: config.adaptiveBitrate,
            initialBitrate: liveVideoBitrate
        )
        abrMonitor = monitor
        await monitor.start()

        abrMonitorTask = Task { [weak self] in
            let stream = await monitor.recommendations
            for await recommendation in stream {
                guard !Task.isCancelled else { return }
                await self?.handleBitrateRecommendation(recommendation)
            }
        }
    }

    /// Handles a bitrate recommendation from the ABR monitor.
    internal func handleBitrateRecommendation(
        _ recommendation: BitrateRecommendation
    ) {
        liveVideoBitrate = recommendation.recommendedBitrate
        emitEvent(.bitrateRecommendation(recommendation))
        emitEvent(.networkSnapshot(recommendation.triggerMetrics))
    }

    /// Computes a congestion level from 0.0 (none) to 1.0 (severe)
    /// based on the current network snapshot and configuration.
    internal func computeCongestionLevel(
        from snapshot: NetworkSnapshot,
        configuration: RTMPConfiguration
    ) -> Double {
        guard snapshot.pendingBytes > 0 else { return 0.0 }
        let window = configuration.adaptiveBitrate.configuration?.measurementWindow ?? 3.0
        let threshold = Double(liveVideoBitrate) * window / 8.0
        guard threshold > 0 else { return 0.0 }
        return min(1.0, Double(snapshot.pendingBytes) / threshold)
    }

    /// Forwards an RTT measurement to the ABR monitor if active.
    internal func recordRTTForABR(_ rtt: Double) async {
        await abrMonitor?.recordRTT(rtt)
    }
}
