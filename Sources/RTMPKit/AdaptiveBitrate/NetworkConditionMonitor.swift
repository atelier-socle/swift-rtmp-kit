// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch

/// Monitors network conditions and emits adaptive bitrate recommendations.
///
/// The monitor consumes raw measurements (RTT, bytes sent, frame events)
/// from the publisher and produces ``BitrateRecommendation`` values via
/// an `AsyncStream`. It implements EWMA bandwidth estimation,
/// RTT baseline tracking, and congestion-aware step-down/step-up logic.
public actor NetworkConditionMonitor {

    // MARK: - Public API

    /// The policy that drives all recommendations. Can be updated at any time.
    public private(set) var policy: AdaptiveBitratePolicy

    /// The current bitrate tracked by the monitor (updated on each recommendation).
    public private(set) var currentBitrate: Int

    /// Current network snapshot (updated after every measurement ingestion).
    public private(set) var currentSnapshot: NetworkSnapshot?

    /// Continuous stream of bitrate recommendations. Finishes when the monitor is stopped.
    public var recommendations: AsyncStream<BitrateRecommendation> {
        stream
    }

    // MARK: - Private State

    private let initialBitrate: Int
    private var stream: AsyncStream<BitrateRecommendation>
    private var continuation: AsyncStream<BitrateRecommendation>.Continuation?

    private var isRunning = false
    private var startTimestamp: Double?

    // EWMA bandwidth estimation
    private var ewmaBandwidth: Double = 0.0
    private var sampleCount: Int = 0

    // RTT tracking
    private var rttSamples: [Double] = []
    private var rttBaseline: Double?
    private var baselineEstablished = false

    // Frame tracking
    private var totalFrames: Int = 0
    private var droppedFrames: Int = 0

    // Pending bytes
    private var lastPendingBytes: Int = 0

    // Cooldown and stability
    private var lastRecommendationTimestamp: Double = 0.0
    private var lastStepDownTimestamp: Double = 0.0

    // MARK: - Constants

    private let cooldownDuration: Double = 2.0

    // MARK: - Lifecycle

    /// Creates a new network condition monitor.
    ///
    /// - Parameters:
    ///   - policy: The adaptive bitrate policy to use.
    ///   - initialBitrate: The starting bitrate in bits per second.
    public init(policy: AdaptiveBitratePolicy, initialBitrate: Int) {
        self.policy = policy
        self.initialBitrate = initialBitrate
        self.currentBitrate = initialBitrate

        let (newStream, newContinuation) = AsyncStream.makeStream(of: BitrateRecommendation.self)
        self.stream = newStream
        self.continuation = newContinuation
    }

    /// Starts the monitor. Measurements recorded after this call will be processed.
    public func start() {
        isRunning = true
        startTimestamp = currentTime()
    }

    /// Stops the monitor and finishes the recommendations stream.
    public func stop() {
        isRunning = false
        continuation?.finish()
        continuation = nil
    }

    /// Resets all internal state to initial values.
    ///
    /// The monitor remains in whatever running state it was in.
    /// A new recommendations stream is created.
    public func reset() {
        currentBitrate = initialBitrate
        currentSnapshot = nil
        ewmaBandwidth = 0.0
        sampleCount = 0
        rttSamples = []
        rttBaseline = nil
        baselineEstablished = false
        totalFrames = 0
        droppedFrames = 0
        lastPendingBytes = 0
        lastRecommendationTimestamp = 0.0
        lastStepDownTimestamp = 0.0
        emittedRecommendations = []
        startTimestamp = isRunning ? currentTime() : nil
    }

    /// Updates the adaptive bitrate policy at runtime.
    ///
    /// - Parameter newPolicy: The new policy to apply.
    public func setPolicy(_ newPolicy: AdaptiveBitratePolicy) {
        policy = newPolicy
    }

    // MARK: - Measurement Ingestion

    /// Records a new RTT measurement in seconds.
    ///
    /// - Parameter rtt: Round-trip time in seconds.
    public func recordRTT(_ rtt: Double) {
        guard isRunning else { return }
        rttSamples.append(rtt)
        updateRTTBaseline(rtt)
        updateSnapshotAndEvaluate()
    }

    /// Records newly sent bytes and the current pending (unacknowledged) byte count.
    ///
    /// - Parameters:
    ///   - bytes: Number of bytes just sent.
    ///   - pendingBytes: Current unacknowledged bytes in the send buffer.
    public func recordBytesSent(_ bytes: Int, pendingBytes: Int) {
        guard isRunning else { return }
        lastPendingBytes = pendingBytes
        updateBandwidthEstimate(bytesSent: bytes)
        updateSnapshotAndEvaluate()
    }

    /// Records a dropped frame event.
    public func recordDroppedFrame() {
        guard isRunning else { return }
        droppedFrames += 1
        totalFrames += 1
        updateSnapshotAndEvaluate()
    }

    /// Records a successfully sent frame.
    public func recordSentFrame() {
        guard isRunning else { return }
        totalFrames += 1
    }

    // MARK: - Manual Override

    /// Forces an immediate bitrate change and emits a recommendation with reason `.manual`.
    ///
    /// - Parameter bitrate: The target bitrate in bits per second.
    public func forceRecommendation(bitrate: Int) {
        let snapshot = buildSnapshot()
        let recommendation = BitrateRecommendation(
            previousBitrate: currentBitrate,
            recommendedBitrate: bitrate,
            reason: .manual,
            triggerMetrics: snapshot
        )
        currentBitrate = bitrate
        currentSnapshot = snapshot
        emitRecommendation(recommendation)
    }

    // MARK: - Internal (Testing)

    /// Stores emitted recommendations in an internal buffer for test access.
    internal private(set) var emittedRecommendations: [BitrateRecommendation] = []

    // MARK: - Private Helpers

    private func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000.0
    }

    private func updateBandwidthEstimate(bytesSent: Int) {
        let bitsSent = Double(bytesSent * 8)
        sampleCount += 1

        guard let config = policy.configuration else { return }
        let windowSamples = max(1, Int(config.measurementWindow * 10))
        let alpha = 2.0 / (Double(windowSamples) + 1.0)

        if sampleCount == 1 {
            ewmaBandwidth = bitsSent
        } else {
            ewmaBandwidth = alpha * bitsSent + (1.0 - alpha) * ewmaBandwidth
        }
    }

    private func updateRTTBaseline(_ rtt: Double) {
        guard let config = policy.configuration, let start = startTimestamp else { return }
        let elapsed = currentTime() - start

        if !baselineEstablished {
            if rttBaseline == nil || rtt < (rttBaseline ?? .infinity) {
                rttBaseline = rtt
            }
            if elapsed >= config.upStabilityDuration {
                baselineEstablished = true
            }
        }
    }

    private func computeDropRate() -> Double {
        guard totalFrames > 0 else { return 0.0 }
        return Double(droppedFrames) / Double(totalFrames)
    }

    private func buildSnapshot() -> NetworkSnapshot {
        NetworkSnapshot(
            estimatedBandwidth: Int(ewmaBandwidth),
            roundTripTime: rttSamples.last,
            rttBaseline: rttBaseline,
            dropRate: computeDropRate(),
            pendingBytes: lastPendingBytes,
            timestamp: currentTime()
        )
    }

    private func updateSnapshotAndEvaluate() {
        let snapshot = buildSnapshot()
        currentSnapshot = snapshot

        guard let config = policy.configuration else { return }
        guard !isInCooldown() else { return }

        if let stepDownReason = checkStepDownTriggers(config: config, snapshot: snapshot) {
            applyStepDown(config: config, reason: stepDownReason, snapshot: snapshot)
        } else if shouldStepUp(config: config, snapshot: snapshot) {
            applyStepUp(config: config, snapshot: snapshot)
        }
    }

    private func isInCooldown() -> Bool {
        let now = currentTime()
        return (now - lastRecommendationTimestamp) < cooldownDuration
    }

    private func checkStepDownTriggers(
        config: AdaptiveBitrateConfiguration,
        snapshot: NetworkSnapshot
    ) -> BitrateChangeReason? {
        if let reason = checkRTTSpike(config: config) {
            return reason
        }
        if let reason = checkCongestion(config: config) {
            return reason
        }
        if let reason = checkDropRate(config: config) {
            return reason
        }
        return nil
    }

    private func checkRTTSpike(config: AdaptiveBitrateConfiguration) -> BitrateChangeReason? {
        guard baselineEstablished,
            let baseline = rttBaseline,
            let latestRTT = rttSamples.last
        else { return nil }

        let threshold = baseline * (1.0 + config.downTriggerThreshold)
        if latestRTT > threshold {
            return .rttSpike
        }
        return nil
    }

    private func checkCongestion(config: AdaptiveBitrateConfiguration) -> BitrateChangeReason? {
        let pendingThreshold = Int(Double(currentBitrate) * config.measurementWindow / 8.0)
        if lastPendingBytes > pendingThreshold {
            return .congestionDetected
        }
        return nil
    }

    private func checkDropRate(config: AdaptiveBitrateConfiguration) -> BitrateChangeReason? {
        let dropRate = computeDropRate()
        if dropRate > config.dropRateTriggerThreshold {
            return .dropRateExceeded
        }
        return nil
    }

    private func shouldStepUp(
        config: AdaptiveBitrateConfiguration,
        snapshot: NetworkSnapshot
    ) -> Bool {
        guard currentBitrate < config.maxBitrate else { return false }

        let now = currentTime()
        let timeSinceLastStepDown = now - lastStepDownTimestamp
        guard timeSinceLastStepDown >= config.upStabilityDuration else { return false }

        let bandwidthThreshold = Double(currentBitrate) * 1.15
        guard ewmaBandwidth >= bandwidthThreshold else { return false }

        return true
    }

    private func applyStepDown(
        config: AdaptiveBitrateConfiguration,
        reason: BitrateChangeReason,
        snapshot: NetworkSnapshot
    ) {
        let newBitrate = max(config.minBitrate, Int(Double(currentBitrate) * config.stepDown))
        let recommendation = BitrateRecommendation(
            previousBitrate: currentBitrate,
            recommendedBitrate: newBitrate,
            reason: reason,
            triggerMetrics: snapshot
        )
        currentBitrate = newBitrate
        lastStepDownTimestamp = currentTime()
        emitRecommendation(recommendation)
    }

    private func applyStepUp(
        config: AdaptiveBitrateConfiguration,
        snapshot: NetworkSnapshot
    ) {
        let newBitrate = min(config.maxBitrate, Int(Double(currentBitrate) * config.stepUp))
        let recommendation = BitrateRecommendation(
            previousBitrate: currentBitrate,
            recommendedBitrate: newBitrate,
            reason: .bandwidthRecovered,
            triggerMetrics: snapshot
        )
        currentBitrate = newBitrate
        emitRecommendation(recommendation)
    }

    private func emitRecommendation(_ recommendation: BitrateRecommendation) {
        lastRecommendationTimestamp = currentTime()
        emittedRecommendations.append(recommendation)
        continuation?.yield(recommendation)
    }
}
