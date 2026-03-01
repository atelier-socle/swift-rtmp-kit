// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Monitoring Showcase")
struct MonitoringShowcaseTests {

    // MARK: - ConnectionMonitor Lifecycle

    @Test(
        "Monitor tracks bytes and frames during streaming"
    )
    func tracksBytesAndFrames() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)

        // Simulate 5 seconds of streaming:
        // 1000 bytes/s sent, 30fps video, 43fps audio
        let ns: UInt64 = 1_000_000_000
        for sec in 1...5 {
            monitor.recordBytesSent(
                1000, at: UInt64(sec) * ns
            )
        }
        for _ in 0..<150 {
            monitor.recordVideoFrameSent()
        }
        for _ in 0..<215 {
            monitor.recordAudioFrameSent()
        }

        let stats = monitor.snapshot(
            currentTime: 5 * ns
        )

        #expect(stats.bytesSent == 5000)
        #expect(stats.videoFramesSent == 150)
        #expect(stats.audioFramesSent == 215)
        #expect(stats.totalFramesSent == 365)

        // Uptime should be ~5.0 seconds
        #expect(stats.connectionUptime >= 4.9)
        #expect(stats.connectionUptime <= 5.1)
    }

    @Test("Bitrate calculation with sliding window")
    func bitrateCalculation() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)

        let ns: UInt64 = 1_000_000_000

        // Send 1000 bytes/s for 10 seconds
        for sec in 1...10 {
            monitor.recordBytesSent(
                1000, at: UInt64(sec) * ns
            )
        }

        let currentBps = monitor.currentBitrate(
            at: 10 * ns
        )
        let averageBps = monitor.averageBitrate(
            at: 10 * ns
        )

        // Sliding window [5s..10s] captures 6 samples
        // (t=5,6,7,8,9,10): 6000 bytes / 5s × 8 = 9600 bps
        #expect(currentBps > 9000)
        #expect(currentBps < 10_000)

        // Average over full 10s: 10000 bytes / 10s × 8 = 8000 bps
        #expect(averageBps > 7500)
        #expect(averageBps < 8500)
    }

    @Test("Dropped frame tracking and drop rate")
    func droppedFrameTracking() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)

        // Send 100 video frames
        for _ in 0..<100 {
            monitor.recordVideoFrameSent()
        }

        // Record 5 dropped frames
        for _ in 0..<5 {
            monitor.recordDroppedFrame()
        }

        let stats = monitor.snapshot(
            currentTime: 1_000_000_000
        )

        #expect(stats.droppedFrames == 5)
        #expect(stats.videoFramesSent == 100)

        // dropRate = 5 / (100+5) × 100 ≈ 4.76%
        #expect(stats.dropRate > 4.7)
        #expect(stats.dropRate < 4.8)
    }

    @Test("RTT measurement via ping/pong")
    func rttMeasurement() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)

        // Send ping at 1000ns, receive pong at 1050ns
        let pingTime: UInt64 = 1_000_000_000
        let pongTime: UInt64 = 1_050_000_000
        monitor.recordPingSent(at: pingTime)
        monitor.recordPongReceived(
            originalTimestamp: pingTime,
            currentTime: pongTime
        )

        let stats = monitor.snapshot(
            currentTime: 2_000_000_000
        )

        // RTT = 50ms = 0.05 seconds
        #expect(stats.roundTripTime != nil)
        if let rtt = stats.roundTripTime {
            #expect(rtt >= 0.049)
            #expect(rtt <= 0.051)
        }
    }

    @Test("Monitor reset clears all counters")
    func resetClearsCounters() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)
        monitor.recordBytesSent(
            5000, at: 1_000_000_000
        )
        monitor.recordBytesReceived(2000)
        monitor.recordVideoFrameSent()
        monitor.recordAudioFrameSent()
        monitor.recordDroppedFrame()
        monitor.recordPingSent(at: 100)
        monitor.recordPongReceived(
            originalTimestamp: 100, currentTime: 150
        )
        monitor.recordAcknowledgement(
            at: 500_000_000
        )

        // Reset everything
        monitor.reset()

        let stats = monitor.snapshot(
            currentTime: 2_000_000_000
        )

        #expect(stats.bytesSent == 0)
        #expect(stats.bytesReceived == 0)
        #expect(stats.videoFramesSent == 0)
        #expect(stats.audioFramesSent == 0)
        #expect(stats.droppedFrames == 0)
        #expect(stats.currentBitrate == 0)
        #expect(stats.averageBitrate == 0)
        #expect(stats.connectionUptime == 0)
        #expect(stats.roundTripTime == nil)
        #expect(stats.lastAcknowledgementTime == nil)
    }

    @Test("Acknowledgement tracking")
    func acknowledgementTracking() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)

        monitor.recordAcknowledgement(
            at: 1_000_000_000
        )

        let stats = monitor.snapshot(
            currentTime: 2_000_000_000
        )

        // lastAcknowledgementTime should be set
        #expect(stats.lastAcknowledgementTime != nil)
        if let ackTime = stats.lastAcknowledgementTime {
            #expect(ackTime >= 0.9)
            #expect(ackTime <= 1.1)
        }
    }

    // MARK: - ConnectionStatistics

    @Test("Statistics snapshot is an immutable value")
    func statisticsSnapshot() {
        var stats = ConnectionStatistics()

        // All defaults are zero
        #expect(stats.bytesSent == 0)
        #expect(stats.bytesReceived == 0)
        #expect(stats.audioFramesSent == 0)
        #expect(stats.videoFramesSent == 0)
        #expect(stats.droppedFrames == 0)
        #expect(stats.totalFramesSent == 0)
        #expect(stats.dropRate == 0)

        // Set values
        stats.audioFramesSent = 100
        stats.videoFramesSent = 200

        // Computed property works
        #expect(stats.totalFramesSent == 300)

        // Equatable: two snapshots with same values
        var stats2 = ConnectionStatistics()
        stats2.audioFramesSent = 100
        stats2.videoFramesSent = 200
        #expect(stats == stats2)
    }

    @Test("Statistics with real-world stream values")
    func realWorldStatistics() {
        var stats = ConnectionStatistics()

        // 1-hour Twitch stream at ~5 Mbps
        stats.bytesSent = 2_250_000_000
        stats.audioFramesSent = 154_350  // 43fps × 3600s
        stats.videoFramesSent = 108_000  // 30fps × 3600s
        stats.droppedFrames = 12
        stats.connectionUptime = 3600.0
        stats.currentBitrate = 5_000_000

        #expect(stats.totalFramesSent == 262_350)

        // Drop rate: 12 / (262350+12) × 100 ≈ 0.0046%
        #expect(stats.dropRate < 0.005)
        #expect(stats.dropRate > 0.004)
    }

    // MARK: - RTMPStatusCode

    @Test(
        "Parse all known RTMP status codes from raw strings"
    )
    func parseAllStatusCodes() {
        let mapping: [(String, RTMPStatusCode)] = [
            (
                "NetStream.Publish.Start",
                .publishStart
            ),
            (
                "NetStream.Publish.BadName",
                .publishBadName
            ),
            (
                "NetStream.Publish.Idle",
                .publishIdle
            ),
            (
                "NetStream.Publish.Rejected",
                .publishRejected
            ),
            (
                "NetStream.Unpublish.Success",
                .unpublishSuccess
            ),
            (
                "NetConnection.Connect.Success",
                .connectSuccess
            ),
            (
                "NetConnection.Connect.Rejected",
                .connectRejected
            ),
            (
                "NetConnection.Connect.Closed",
                .connectClosed
            ),
            (
                "NetConnection.Connect.Failed",
                .connectFailed
            ),
            (
                "NetStream.Play.Reset",
                .streamReset
            ),
            ("NetStream.Failed", .streamFailed)
        ]

        // All 11 codes parse correctly
        #expect(mapping.count == 11)
        for (raw, expected) in mapping {
            let parsed = RTMPStatusCode(rawValue: raw)
            #expect(parsed == expected)
        }

        // Unknown string → nil
        #expect(
            RTMPStatusCode(rawValue: "Unknown.Code")
                == nil
        )
    }

    @Test("Status code classification: success vs error")
    func statusCodeClassification() {
        // Success codes
        #expect(RTMPStatusCode.publishStart.isSuccess)
        #expect(
            RTMPStatusCode.connectSuccess.isSuccess
        )
        #expect(
            RTMPStatusCode.unpublishSuccess.isSuccess
        )

        // Error codes
        #expect(RTMPStatusCode.publishBadName.isError)
        #expect(
            RTMPStatusCode.connectRejected.isError
        )
        #expect(RTMPStatusCode.connectFailed.isError)
        #expect(RTMPStatusCode.streamFailed.isError)
        #expect(RTMPStatusCode.connectClosed.isError)
        #expect(
            RTMPStatusCode.publishRejected.isError
        )

        // Codes that are neither
        #expect(!RTMPStatusCode.publishIdle.isSuccess)
        #expect(!RTMPStatusCode.publishIdle.isError)
        #expect(!RTMPStatusCode.streamReset.isSuccess)
        #expect(!RTMPStatusCode.streamReset.isError)
    }

    @Test("Status code categories")
    func statusCodeCategories() {
        // Connection category
        let connectionCodes: [RTMPStatusCode] = [
            .connectSuccess, .connectRejected,
            .connectClosed, .connectFailed
        ]
        for code in connectionCodes {
            #expect(code.category == .connection)
        }

        // Publish category
        let publishCodes: [RTMPStatusCode] = [
            .publishStart, .publishBadName,
            .publishIdle, .publishRejected,
            .unpublishSuccess
        ]
        for code in publishCodes {
            #expect(code.category == .publish)
        }

        // Stream category
        let streamCodes: [RTMPStatusCode] = [
            .streamReset, .streamFailed
        ]
        for code in streamCodes {
            #expect(code.category == .stream)
        }
    }

    @Test(
        "RTMPEvent.statisticsUpdate carries statistics"
    )
    func statisticsUpdateEvent() {
        var stats = ConnectionStatistics()
        stats.bytesSent = 42_000
        stats.videoFramesSent = 60

        let event = RTMPEvent.statisticsUpdate(stats)

        // Pattern match and verify payload
        if case .statisticsUpdate(let payload) = event {
            #expect(payload.bytesSent == 42_000)
            #expect(payload.videoFramesSent == 60)
        } else {
            Issue.record("Expected .statisticsUpdate")
        }
    }
}
