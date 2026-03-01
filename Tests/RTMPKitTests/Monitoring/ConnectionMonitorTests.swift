// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

/// Nanoseconds helper: 1 second = 1_000_000_000 ns.
private let oneSecondNs: UInt64 = 1_000_000_000

// MARK: - Recording

@Suite("ConnectionMonitor — Recording")
struct ConnectionMonitorRecordingTests {

    @Test("recordBytesSent accumulates total")
    func bytesSentAccumulates() {
        var monitor = ConnectionMonitor()
        monitor.recordBytesSent(100, at: oneSecondNs)
        monitor.recordBytesSent(200, at: 2 * oneSecondNs)
        let stats = monitor.snapshot(currentTime: 3 * oneSecondNs)
        #expect(stats.bytesSent == 300)
    }

    @Test("recordBytesReceived accumulates total")
    func bytesReceivedAccumulates() {
        var monitor = ConnectionMonitor()
        monitor.recordBytesReceived(100)
        monitor.recordBytesReceived(200)
        let stats = monitor.snapshot(currentTime: oneSecondNs)
        #expect(stats.bytesReceived == 300)
    }

    @Test("recordAudioFrameSent increments count")
    func audioFrameIncrement() {
        var monitor = ConnectionMonitor()
        monitor.recordAudioFrameSent()
        monitor.recordAudioFrameSent()
        monitor.recordAudioFrameSent()
        let stats = monitor.snapshot(currentTime: oneSecondNs)
        #expect(stats.audioFramesSent == 3)
    }

    @Test("recordVideoFrameSent increments count")
    func videoFrameIncrement() {
        var monitor = ConnectionMonitor()
        monitor.recordVideoFrameSent()
        monitor.recordVideoFrameSent()
        let stats = monitor.snapshot(currentTime: oneSecondNs)
        #expect(stats.videoFramesSent == 2)
    }

    @Test("recordDroppedFrame increments count")
    func droppedFrameIncrement() {
        var monitor = ConnectionMonitor()
        monitor.recordDroppedFrame()
        monitor.recordDroppedFrame()
        let stats = monitor.snapshot(currentTime: oneSecondNs)
        #expect(stats.droppedFrames == 2)
    }

    @Test("multiple records accumulate correctly")
    func multipleRecords() {
        var monitor = ConnectionMonitor()
        monitor.recordBytesSent(1000, at: oneSecondNs)
        monitor.recordBytesReceived(500)
        monitor.recordAudioFrameSent()
        monitor.recordVideoFrameSent()
        monitor.recordVideoFrameSent()
        monitor.recordDroppedFrame()

        let stats = monitor.snapshot(currentTime: 2 * oneSecondNs)
        #expect(stats.bytesSent == 1000)
        #expect(stats.bytesReceived == 500)
        #expect(stats.audioFramesSent == 1)
        #expect(stats.videoFramesSent == 2)
        #expect(stats.droppedFrames == 1)
    }
}

// MARK: - Bitrate

@Suite("ConnectionMonitor — Bitrate")
struct ConnectionMonitorBitrateTests {

    @Test("currentBitrate returns 0 before any data sent")
    func bitrateZeroBeforeData() {
        let monitor = ConnectionMonitor()
        #expect(monitor.currentBitrate(at: oneSecondNs) == 0)
    }

    @Test("averageBitrate returns 0 before any data sent")
    func avgBitrateZeroBeforeData() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)
        #expect(monitor.averageBitrate(at: oneSecondNs) == 0)
    }

    @Test("currentBitrate after single sample")
    func bitrateAfterSingleSample() {
        var monitor = ConnectionMonitor(bitrateWindowSize: 5.0)
        monitor.recordBytesSent(1000, at: oneSecondNs)
        // 1000 bytes over ~1s window: 1000 * 8 / 1 = 8000 bps
        let bitrate = monitor.currentBitrate(at: 2 * oneSecondNs)
        #expect(bitrate > 0)
    }

    @Test("currentBitrate with multiple samples in window")
    func bitrateMultipleSamples() {
        var monitor = ConnectionMonitor(bitrateWindowSize: 5.0)
        monitor.recordBytesSent(500, at: oneSecondNs)
        monitor.recordBytesSent(500, at: 2 * oneSecondNs)
        let bitrate = monitor.currentBitrate(at: 3 * oneSecondNs)
        // 1000 bytes over 2s = 1000 * 8 / 2 = 4000 bps
        #expect(bitrate > 0)
    }

    @Test("currentBitrate excludes old samples outside window")
    func bitrateExcludesOldSamples() {
        var monitor = ConnectionMonitor(bitrateWindowSize: 2.0)
        // Send 1000 bytes at t=1s
        monitor.recordBytesSent(1000, at: oneSecondNs)
        // Send 500 bytes at t=5s
        monitor.recordBytesSent(500, at: 5 * oneSecondNs)
        // At t=6s, window is [4s, 6s], only the 500-byte sample is in window
        let bitrate = monitor.currentBitrate(at: 6 * oneSecondNs)
        // 500 bytes over 1s = 500 * 8 / 1 = 4000 bps
        #expect(bitrate == 4000)
    }

    @Test("averageBitrate from connection start")
    func avgBitrateFromStart() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)
        monitor.recordBytesSent(1000, at: oneSecondNs)
        // 1000 bytes over 2s: 1000 * 8 / 2 = 4000 bps
        let avg = monitor.averageBitrate(at: 2 * oneSecondNs)
        #expect(avg == 4000)
    }

    @Test("averageBitrate returns 0 at connection start")
    func avgBitrateAtStart() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: oneSecondNs)
        #expect(monitor.averageBitrate(at: oneSecondNs) == 0)
    }
}

// MARK: - Timing

@Suite("ConnectionMonitor — Timing")
struct ConnectionMonitorTimingTests {

    @Test("markConnectionStart sets start time")
    func markStart() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: oneSecondNs)
        let stats = monitor.snapshot(currentTime: 3 * oneSecondNs)
        #expect(stats.connectionUptime == 2.0)
    }

    @Test("snapshot uptime shows correct elapsed time")
    func uptimeCorrect() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)
        let stats = monitor.snapshot(currentTime: 5 * oneSecondNs)
        #expect(stats.connectionUptime == 5.0)
    }

    @Test("recordPongReceived with currentTime calculates RTT")
    func rttCalculation() {
        var monitor = ConnectionMonitor()
        monitor.recordPingSent(at: oneSecondNs)
        monitor.recordPongReceived(
            originalTimestamp: oneSecondNs,
            currentTime: oneSecondNs + 50_000_000  // 50ms
        )
        let stats = monitor.snapshot(currentTime: 2 * oneSecondNs)
        #expect(stats.roundTripTime != nil)
        if let rtt = stats.roundTripTime {
            #expect(rtt >= 0.049 && rtt <= 0.051)
        }
    }

    @Test("recordAcknowledgement sets lastAcknowledgementTime")
    func ackTime() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)
        monitor.recordAcknowledgement(at: 2 * oneSecondNs)
        let stats = monitor.snapshot(currentTime: 3 * oneSecondNs)
        #expect(stats.lastAcknowledgementTime == 2.0)
    }
}

// MARK: - Lifecycle

@Suite("ConnectionMonitor — Lifecycle")
struct ConnectionMonitorLifecycleTests {

    @Test("reset zeroes all counters")
    func resetZeroes() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)
        monitor.recordBytesSent(1000, at: oneSecondNs)
        monitor.recordBytesReceived(500)
        monitor.recordAudioFrameSent()
        monitor.recordVideoFrameSent()
        monitor.recordDroppedFrame()
        monitor.recordAcknowledgement(at: oneSecondNs)

        monitor.reset()

        let stats = monitor.snapshot(currentTime: 2 * oneSecondNs)
        #expect(stats.bytesSent == 0)
        #expect(stats.bytesReceived == 0)
        #expect(stats.audioFramesSent == 0)
        #expect(stats.videoFramesSent == 0)
        #expect(stats.droppedFrames == 0)
        #expect(stats.connectionUptime == 0)
        #expect(stats.lastAcknowledgementTime == nil)
        #expect(stats.roundTripTime == nil)
    }

    @Test("snapshot returns complete ConnectionStatistics")
    func snapshotComplete() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)
        monitor.recordBytesSent(2000, at: oneSecondNs)
        monitor.recordBytesReceived(1000)
        monitor.recordAudioFrameSent()
        monitor.recordVideoFrameSent()
        monitor.recordVideoFrameSent()

        let stats = monitor.snapshot(currentTime: 2 * oneSecondNs)
        #expect(stats.bytesSent == 2000)
        #expect(stats.bytesReceived == 1000)
        #expect(stats.audioFramesSent == 1)
        #expect(stats.videoFramesSent == 2)
        #expect(stats.totalFramesSent == 3)
        #expect(stats.connectionUptime == 2.0)
        #expect(stats.averageBitrate > 0)
    }
}
