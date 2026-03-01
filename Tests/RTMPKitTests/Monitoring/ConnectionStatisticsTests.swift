// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Default Values

@Suite("ConnectionStatistics — Default Values")
struct ConnectionStatisticsDefaultTests {

    @Test("default init has all zeros")
    func defaultInit() {
        let stats = ConnectionStatistics()
        #expect(stats.bytesSent == 0)
        #expect(stats.bytesReceived == 0)
        #expect(stats.audioFramesSent == 0)
        #expect(stats.videoFramesSent == 0)
        #expect(stats.droppedFrames == 0)
        #expect(stats.currentBitrate == 0)
        #expect(stats.averageBitrate == 0)
        #expect(stats.connectionUptime == 0)
        #expect(stats.lastAcknowledgementTime == nil)
        #expect(stats.roundTripTime == nil)
    }

    @Test("totalFramesSent is audio + video")
    func totalFramesSent() {
        var stats = ConnectionStatistics()
        stats.audioFramesSent = 30
        stats.videoFramesSent = 70
        #expect(stats.totalFramesSent == 100)
    }

    @Test("totalFramesSent is zero when no frames sent")
    func totalFramesSentZero() {
        let stats = ConnectionStatistics()
        #expect(stats.totalFramesSent == 0)
    }
}

// MARK: - Drop Rate

@Suite("ConnectionStatistics — Drop Rate")
struct ConnectionStatisticsDropRateTests {

    @Test("dropRate is 0 when no frames sent")
    func dropRateZeroNoFrames() {
        let stats = ConnectionStatistics()
        #expect(stats.dropRate == 0)
    }

    @Test("dropRate is 0 when no dropped frames")
    func dropRateZeroNoDrops() {
        var stats = ConnectionStatistics()
        stats.videoFramesSent = 100
        #expect(stats.dropRate == 0)
    }

    @Test("dropRate calculates correct percentage")
    func dropRateCorrectPercentage() {
        var stats = ConnectionStatistics()
        stats.videoFramesSent = 95
        stats.droppedFrames = 5
        // 5 / (95 + 5) * 100 = 5.0
        #expect(stats.dropRate == 5.0)
    }

    @Test("dropRate with mixed audio and video")
    func dropRateMixed() {
        var stats = ConnectionStatistics()
        stats.audioFramesSent = 50
        stats.videoFramesSent = 45
        stats.droppedFrames = 5
        // 5 / (50 + 45 + 5) * 100 = 5.0
        #expect(stats.dropRate == 5.0)
    }
}

// MARK: - Equatable & Properties

@Suite("ConnectionStatistics — Properties")
struct ConnectionStatisticsPropertiesTests {

    @Test("all properties are settable and readable")
    func settableProperties() {
        var stats = ConnectionStatistics()
        stats.bytesSent = 1000
        stats.bytesReceived = 500
        stats.audioFramesSent = 10
        stats.videoFramesSent = 20
        stats.droppedFrames = 2
        stats.currentBitrate = 5000.0
        stats.averageBitrate = 4500.0
        stats.connectionUptime = 60.0
        stats.lastAcknowledgementTime = 59.5
        stats.roundTripTime = 0.05

        #expect(stats.bytesSent == 1000)
        #expect(stats.bytesReceived == 500)
        #expect(stats.audioFramesSent == 10)
        #expect(stats.videoFramesSent == 20)
        #expect(stats.droppedFrames == 2)
        #expect(stats.currentBitrate == 5000.0)
        #expect(stats.averageBitrate == 4500.0)
        #expect(stats.connectionUptime == 60.0)
        #expect(stats.lastAcknowledgementTime == 59.5)
        #expect(stats.roundTripTime == 0.05)
    }

    @Test("same values are equal")
    func sameValuesEqual() {
        var a = ConnectionStatistics()
        a.bytesSent = 100
        var b = ConnectionStatistics()
        b.bytesSent = 100
        #expect(a == b)
    }

    @Test("different values are not equal")
    func differentValuesNotEqual() {
        var a = ConnectionStatistics()
        a.bytesSent = 100
        var b = ConnectionStatistics()
        b.bytesSent = 200
        #expect(a != b)
    }

    @Test("bytesSent and bytesReceived are independent")
    func bytesIndependent() {
        var stats = ConnectionStatistics()
        stats.bytesSent = 1000
        stats.bytesReceived = 500
        #expect(stats.bytesSent == 1000)
        #expect(stats.bytesReceived == 500)
    }
}
