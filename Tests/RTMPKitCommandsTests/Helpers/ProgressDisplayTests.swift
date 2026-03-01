// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKitCommands

@Suite("ProgressDisplay — formatBytes")
struct ProgressDisplayFormatBytesTests {

    @Test("0 bytes formats as '0 B'")
    func zeroBytes() {
        #expect(ProgressDisplay.formatBytes(0) == "0 B")
    }

    @Test("1024 bytes formats as '1.0 KB'")
    func kilobytes() {
        #expect(ProgressDisplay.formatBytes(1024) == "1.0 KB")
    }

    @Test("1_048_576 bytes formats as '1.0 MB'")
    func megabytes() {
        #expect(
            ProgressDisplay.formatBytes(1_048_576) == "1.0 MB"
        )
    }

    @Test("1_073_741_824 bytes formats as '1.0 GB'")
    func gigabytes() {
        #expect(
            ProgressDisplay.formatBytes(1_073_741_824) == "1.0 GB"
        )
    }

    @Test("500 bytes formats as '500 B'")
    func smallBytes() {
        #expect(ProgressDisplay.formatBytes(500) == "500 B")
    }
}

@Suite("ProgressDisplay — formatBitrate")
struct ProgressDisplayFormatBitrateTests {

    @Test("3_500_000 bps formats as '3.5 Mbps'")
    func megabits() {
        #expect(
            ProgressDisplay.formatBitrate(3_500_000) == "3.5 Mbps"
        )
    }

    @Test("128_000 bps formats as '128.0 kbps'")
    func kilobits() {
        #expect(
            ProgressDisplay.formatBitrate(128_000) == "128.0 kbps"
        )
    }
}

@Suite("ProgressDisplay — formatDuration")
struct ProgressDisplayFormatDurationTests {

    @Test("0 seconds formats as '00:00:00'")
    func zeroDuration() {
        #expect(
            ProgressDisplay.formatDuration(0) == "00:00:00"
        )
    }

    @Test("3723 seconds formats as '01:02:03'")
    func hoursMinutesSeconds() {
        #expect(
            ProgressDisplay.formatDuration(3723) == "01:02:03"
        )
    }

    @Test("59 seconds formats as '00:00:59'")
    func secondsOnly() {
        #expect(
            ProgressDisplay.formatDuration(59) == "00:00:59"
        )
    }
}
