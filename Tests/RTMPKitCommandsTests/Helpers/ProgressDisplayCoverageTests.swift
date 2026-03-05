// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import RTMPKit
import Testing

@testable import RTMPKitCommands

@Suite("ProgressDisplay — Instance Methods")
struct ProgressDisplayMethodTests {

    @Test("init creates instance")
    func initCreates() {
        let display = ProgressDisplay()
        _ = display  // Instance created successfully
    }

    @Test("update prints statistics line")
    func updatePrints() {
        let display = ProgressDisplay()
        var stats = ConnectionStatistics()
        stats.bytesSent = 1_000_000
        stats.videoFramesSent = 300
        stats.audioFramesSent = 600
        stats.currentBitrate = 3_500_000
        display.update(
            statistics: stats,
            state: .publishing,
            elapsed: 10.5)
    }

    @Test("showStatus prints info message")
    func showStatusPrints() {
        let display = ProgressDisplay()
        display.showStatus("Connecting to server...")
    }

    @Test("showError prints error message")
    func showErrorPrints() {
        let display = ProgressDisplay()
        display.showError("Connection refused")
    }

    @Test("showSuccess prints success message")
    func showSuccessPrints() {
        let display = ProgressDisplay()
        display.showSuccess("Stream started")
    }

    @Test("clearLine clears terminal line")
    func clearLinePrints() {
        let display = ProgressDisplay()
        display.clearLine()
    }

    @Test("update with idle state")
    func updateIdle() {
        let display = ProgressDisplay()
        display.update(
            statistics: ConnectionStatistics(),
            state: .idle, elapsed: 0)
    }

    @Test("update with connecting state")
    func updateConnecting() {
        let display = ProgressDisplay()
        display.update(
            statistics: ConnectionStatistics(),
            state: .connecting, elapsed: 0)
    }

    @Test("update with handshaking state")
    func updateHandshaking() {
        let display = ProgressDisplay()
        display.update(
            statistics: ConnectionStatistics(),
            state: .handshaking, elapsed: 0)
    }

    @Test("update with connected state")
    func updateConnected() {
        let display = ProgressDisplay()
        display.update(
            statistics: ConnectionStatistics(),
            state: .connected, elapsed: 0)
    }

    @Test("update with reconnecting state")
    func updateReconnecting() {
        let display = ProgressDisplay()
        display.update(
            statistics: ConnectionStatistics(),
            state: .reconnecting(attempt: 3), elapsed: 0)
    }

    @Test("update with disconnected state")
    func updateDisconnected() {
        let display = ProgressDisplay()
        display.update(
            statistics: ConnectionStatistics(),
            state: .disconnected, elapsed: 0)
    }

    @Test("update with failed state")
    func updateFailed() {
        let display = ProgressDisplay()
        display.update(
            statistics: ConnectionStatistics(),
            state: .failed(.connectionTimeout), elapsed: 0)
    }
}
