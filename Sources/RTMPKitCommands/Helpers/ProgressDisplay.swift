// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import RTMPKit

/// Terminal progress display for streaming sessions.
///
/// Shows real-time statistics including bitrate, frames sent,
/// duration, and connection status. Updates in-place using
/// carriage return for a clean terminal experience.
public struct ProgressDisplay: Sendable {

    /// Create a new progress display.
    public init() {}

    /// Update the display with current statistics.
    public func update(
        statistics: ConnectionStatistics,
        state: RTMPPublisherState,
        elapsed: Double
    ) {
        let bitrate = Self.formatBitrate(statistics.currentBitrate)
        let sent = Self.formatBytes(statistics.bytesSent)
        let duration = Self.formatDuration(elapsed)
        let frames = statistics.totalFramesSent
        let dropped = statistics.droppedFrames

        let line =
            "\r\(ColorOutput.info("[\(duration)]")) "
            + "\(bitrate) | \(sent) sent | "
            + "\(frames) frames | \(dropped) dropped | "
            + "\(stateLabel(state))"
        print(line, terminator: "")
        fflush(stdout)
    }

    /// Show a status line (for non-streaming updates).
    public func showStatus(_ message: String) {
        print(ColorOutput.info(message))
    }

    /// Show an error message.
    public func showError(_ message: String) {
        print(ColorOutput.error("Error: \(message)"))
    }

    /// Show a success message.
    public func showSuccess(_ message: String) {
        print(ColorOutput.success(message))
    }

    /// Clear the current line.
    public func clearLine() {
        print("\r\u{1B}[2K", terminator: "")
        fflush(stdout)
    }

    /// Format bytes as human-readable string (e.g., "1.5 MB").
    public static func formatBytes(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0 B" }

        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    /// Format bitrate (e.g., "3.5 Mbps").
    public static func formatBitrate(_ bitsPerSecond: Double) -> String {
        if bitsPerSecond >= 1_000_000 {
            return String(
                format: "%.1f Mbps", bitsPerSecond / 1_000_000
            )
        }
        return String(format: "%.1f kbps", bitsPerSecond / 1000)
    }

    /// Format duration (e.g., "01:23:45").
    public static func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    // MARK: - Private

    private func stateLabel(_ state: RTMPPublisherState) -> String {
        switch state {
        case .idle:
            return ColorOutput.dim("idle")
        case .connecting:
            return ColorOutput.warning("connecting...")
        case .handshaking:
            return ColorOutput.warning("handshaking...")
        case .connected:
            return ColorOutput.info("connected")
        case .publishing:
            return ColorOutput.success("publishing")
        case .reconnecting(let attempt):
            return ColorOutput.warning("reconnecting (\(attempt))...")
        case .disconnected:
            return ColorOutput.dim("disconnected")
        case .failed:
            return ColorOutput.error("failed")
        }
    }
}
