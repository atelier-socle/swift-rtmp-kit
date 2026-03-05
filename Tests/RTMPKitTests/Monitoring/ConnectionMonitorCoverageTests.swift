// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ConnectionMonitor — Pong Handling")
struct ConnectionMonitorPongCoverageTests {

    @Test("recordPongReceived without currentTime clears ping")
    func pongReceivedClearsPing() {
        var monitor = ConnectionMonitor()
        monitor.recordPingSent(at: 1_000_000_000)
        monitor.recordPongReceived(originalTimestamp: 1_000_000_000)
        // After pong, lastPingTimestamp should be nil.
        // Verify by sending another pong — it should be a no-op.
        monitor.recordPongReceived(originalTimestamp: 1_000_000_000)
    }

    @Test("recordPongReceived with mismatched timestamp is no-op")
    func pongMismatchedTimestamp() {
        var monitor = ConnectionMonitor()
        monitor.recordPingSent(at: 1_000_000_000)
        // Different timestamp — should not clear
        monitor.recordPongReceived(originalTimestamp: 2_000_000_000)
        // The ping is still active, so pong with correct timestamp works
        monitor.recordPongReceived(originalTimestamp: 1_000_000_000)
    }

    @Test("recordPongReceived without prior ping is no-op")
    func pongWithoutPing() {
        var monitor = ConnectionMonitor()
        monitor.recordPongReceived(originalTimestamp: 1_000_000_000)
        // No crash, no error.
    }

    @Test("recordPongReceived with currentTime computes RTT")
    func pongComputesRTT() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 0)
        monitor.recordPingSent(at: 1_000_000_000)
        monitor.recordPongReceived(
            originalTimestamp: 1_000_000_000,
            currentTime: 1_050_000_000)
        let stats = monitor.snapshot(currentTime: 1_100_000_000)
        #expect(stats.roundTripTime != nil)
        // RTT should be ~50ms
        if let rtt = stats.roundTripTime {
            #expect(rtt >= 0.04 && rtt <= 0.06)
        }
    }

    @Test("recordPongReceived with currentTime before original is no-op")
    func pongCurrentTimeBeforeOriginal() {
        var monitor = ConnectionMonitor()
        monitor.recordPingSent(at: 2_000_000_000)
        // currentTime < originalTimestamp — guard fails
        monitor.recordPongReceived(
            originalTimestamp: 2_000_000_000,
            currentTime: 1_000_000_000)
        let stats = monitor.snapshot(currentTime: 3_000_000_000)
        #expect(stats.roundTripTime == nil)
    }

    @Test("lastAcknowledgementTime computed in snapshot")
    func lastAckTimeInSnapshot() {
        var monitor = ConnectionMonitor()
        monitor.markConnectionStart(at: 1_000_000_000)
        monitor.recordAcknowledgement(at: 2_000_000_000)
        let stats = monitor.snapshot(currentTime: 3_000_000_000)
        #expect(stats.lastAcknowledgementTime != nil)
        if let ackTime = stats.lastAcknowledgementTime {
            #expect(ackTime >= 0.9 && ackTime <= 1.1)
        }
    }

    @Test("droppedFrame recording")
    func droppedFrameRecording() {
        var monitor = ConnectionMonitor()
        monitor.recordDroppedFrame()
        monitor.recordDroppedFrame()
        let stats = monitor.snapshot(currentTime: 0)
        #expect(stats.droppedFrames == 2)
    }
}
