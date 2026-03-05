// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch

/// Continuously computes connection quality scores during a live stream.
///
/// Owned by ``RTMPPublisher``. Feeds from the same signals as
/// ``NetworkConditionMonitor`` — RTT, bytes sent, frame drops,
/// reconnections, and bitrate achievement.
///
/// Scores are emitted periodically via the ``scores`` async stream.
public actor ConnectionQualityMonitor {

    // MARK: - Configuration

    /// How often to emit a new score (seconds).
    public let scoringInterval: Double

    /// Size of the reporting window (seconds).
    public let reportingWindow: Double

    // MARK: - Private State

    private var isRunning = false
    private var startTimestamp: Double?
    private var scoringTask: Task<Void, Never>?

    // AsyncStream backing
    private var stream: AsyncStream<ConnectionQualityScore>
    private var continuation: AsyncStream<ConnectionQualityScore>.Continuation?

    // Measurement buffers (bounded)
    private var rttSamples: [Double] = []
    private var bytesSentSamples: [(bytes: Int, targetBitrate: Int)] = []
    private var frameDropCount: Int = 0
    private var frameTotalCount: Int = 0
    private var reconnectCount: Int = 0
    private var bitrateActual: Int = 0
    private var bitrateConfigured: Int = 0

    // Score history
    private var scoreHistory: [ConnectionQualityScore] = []
    private var events: [String] = []

    // Warning tracking — only emit when crossing threshold
    private var warnedDimensions: Set<QualityDimension> = []

    // Warning callback (set by publisher for event forwarding)
    private var warningHandler: (@Sendable (QualityDimension, Double) -> Void)?

    /// Current score (most recently computed).
    public private(set) var currentScore: ConnectionQualityScore?

    // MARK: - Lifecycle

    /// Creates a new connection quality monitor.
    ///
    /// - Parameters:
    ///   - scoringInterval: How often to emit scores (seconds). Default: 1.0.
    ///   - reportingWindow: Window size for reports (seconds). Default: 30.0.
    public init(
        scoringInterval: Double = 1.0,
        reportingWindow: Double = 30.0
    ) {
        self.scoringInterval = scoringInterval
        self.reportingWindow = reportingWindow

        let (newStream, newContinuation) = AsyncStream.makeStream(
            of: ConnectionQualityScore.self
        )
        self.stream = newStream
        self.continuation = newContinuation
    }

    /// Start the scoring loop. Call after publisher connects.
    public func start() {
        isRunning = true
        startTimestamp = currentTime()
        startScoringLoop()
    }

    /// Stop the scoring loop and emit a final report.
    ///
    /// - Returns: A quality report if any scores were recorded, or nil.
    public func stop() -> QualityReport? {
        isRunning = false
        scoringTask?.cancel()
        scoringTask = nil
        continuation?.finish()
        continuation = nil

        return generateReport()
    }

    /// Sets a handler called when a dimension crosses the warning threshold.
    ///
    /// - Parameter handler: Callback receiving the dimension and its score.
    public func setWarningHandler(
        _ handler: @escaping @Sendable (QualityDimension, Double) -> Void
    ) {
        self.warningHandler = handler
    }

    // MARK: - Signal Ingestion

    /// Record a new RTT measurement (milliseconds).
    ///
    /// - Parameter rtt: Round-trip time in milliseconds.
    public func recordRTT(_ rtt: Double) {
        guard isRunning else { return }
        rttSamples.append(rtt)
        trimRTTSamples()
    }

    /// Record bytes sent in the last interval.
    ///
    /// - Parameters:
    ///   - bytes: Number of bytes sent.
    ///   - targetBitrate: The target bitrate in bits per second.
    public func recordBytesSent(_ bytes: Int, targetBitrate: Int) {
        guard isRunning else { return }
        bytesSentSamples.append((bytes: bytes, targetBitrate: targetBitrate))
        trimBytesSentSamples()
    }

    /// Record a frame drop event.
    public func recordFrameDrop() {
        guard isRunning else { return }
        frameDropCount += 1
        frameTotalCount += 1
    }

    /// Record a reconnection event.
    public func recordReconnection() {
        guard isRunning else { return }
        reconnectCount += 1
        events.append("reconnection")
    }

    /// Record current vs configured bitrate.
    ///
    /// - Parameters:
    ///   - actual: The actual bitrate being used (bits per second).
    ///   - configured: The configured target bitrate (bits per second).
    public func recordBitrateAchievement(actual: Int, configured: Int) {
        guard isRunning else { return }
        bitrateActual = actual
        bitrateConfigured = configured
    }

    /// Record a sent frame (for drop rate calculation).
    public func recordSentFrame() {
        guard isRunning else { return }
        frameTotalCount += 1
    }

    // MARK: - Output

    /// Continuous stream of quality scores (emitted every ``scoringInterval``).
    public var scores: AsyncStream<ConnectionQualityScore> {
        stream
    }

    /// Generate a quality report for the current window.
    ///
    /// - Returns: A quality report, or nil if no scores have been recorded.
    public func generateReport() -> QualityReport? {
        QualityReport.build(samples: scoreHistory, events: events)
    }

    // MARK: - Private

    private func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000.0
    }

    private func startScoringLoop() {
        let interval = scoringInterval
        scoringTask = Task { [weak self] in
            let intervalNs = UInt64(interval * 1_000_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNs)
                guard !Task.isCancelled else { return }
                await self?.computeAndEmitScore()
            }
        }
    }

    private func computeAndEmitScore() {
        let score = computeScore()
        currentScore = score
        scoreHistory.append(score)
        trimScoreHistory()
        continuation?.yield(score)
        checkWarnings(score)
    }

    private func computeScore() -> ConnectionQualityScore {
        var dims: [QualityDimension: Double] = [:]

        dims[.throughput] = computeThroughputScore()
        dims[.latency] = computeLatencyScore()
        dims[.frameDropRate] = computeFrameDropScore()
        dims[.stability] = computeStabilityScore()
        dims[.bitrateAchievement] = computeBitrateAchievementScore()

        return ConnectionQualityScore(
            dimensions: dims,
            timestamp: currentTime()
        )
    }

    private func computeThroughputScore() -> Double {
        guard !bytesSentSamples.isEmpty else { return 1.0 }
        let totalBytes = bytesSentSamples.reduce(0) { $0 + $1.bytes }
        let avgTarget =
            bytesSentSamples.reduce(0) { $0 + $1.targetBitrate }
            / bytesSentSamples.count
        guard avgTarget > 0 else { return 1.0 }
        let actualBps = Double(totalBytes * 8) / Double(bytesSentSamples.count)
        return min(1.0, actualBps / Double(avgTarget))
    }

    private func computeLatencyScore() -> Double {
        guard !rttSamples.isEmpty else { return 1.0 }
        let avgRTT = rttSamples.reduce(0, +) / Double(rttSamples.count)
        return max(0.0, 1.0 - (avgRTT / 200.0))
    }

    private func computeFrameDropScore() -> Double {
        guard frameTotalCount > 0 else { return 1.0 }
        let dropRate = Double(frameDropCount) / Double(frameTotalCount)
        return max(0.0, 1.0 - (dropRate / 0.05))
    }

    private func computeStabilityScore() -> Double {
        max(0.0, 1.0 - (Double(reconnectCount) / 3.0))
    }

    private func computeBitrateAchievementScore() -> Double {
        guard bitrateConfigured > 0 else { return 1.0 }
        return min(1.0, Double(bitrateActual) / Double(bitrateConfigured))
    }

    private func checkWarnings(_ score: ConnectionQualityScore) {
        let threshold = 0.40
        for (dimension, value) in score.dimensions {
            if value < threshold {
                if !warnedDimensions.contains(dimension) {
                    warnedDimensions.insert(dimension)
                    warningHandler?(dimension, value)
                }
            } else {
                warnedDimensions.remove(dimension)
            }
        }
    }

    private func trimRTTSamples() {
        let maxSamples = max(1, Int(reportingWindow / scoringInterval) * 10)
        if rttSamples.count > maxSamples {
            rttSamples.removeFirst(rttSamples.count - maxSamples)
        }
    }

    private func trimBytesSentSamples() {
        let maxSamples = max(1, Int(reportingWindow / scoringInterval) * 10)
        if bytesSentSamples.count > maxSamples {
            bytesSentSamples.removeFirst(bytesSentSamples.count - maxSamples)
        }
    }

    private func trimScoreHistory() {
        let maxScores = max(1, Int(reportingWindow / scoringInterval))
        if scoreHistory.count > maxScores {
            scoreHistory.removeFirst(scoreHistory.count - maxScores)
        }
    }
}
