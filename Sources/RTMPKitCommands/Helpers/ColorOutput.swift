// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// ANSI color output for terminal display.
///
/// Automatically disables colors when stdout is not a TTY
/// (e.g., piped output or CI environments).
public enum ColorOutput {

    /// Whether color output is enabled (auto-detected from TTY).
    public static var isEnabled: Bool {
        isatty(fileno(stdout)) != 0
    }

    /// Green text — for success messages.
    public static func success(_ text: String) -> String {
        wrap(text, code: "32")
    }

    /// Red text — for error messages.
    public static func error(_ text: String) -> String {
        wrap(text, code: "31")
    }

    /// Yellow text — for warnings.
    public static func warning(_ text: String) -> String {
        wrap(text, code: "33")
    }

    /// Bold text — for emphasis.
    public static func bold(_ text: String) -> String {
        wrap(text, code: "1")
    }

    /// Dim text — for secondary information.
    public static func dim(_ text: String) -> String {
        wrap(text, code: "2")
    }

    /// Cyan text — for info/status.
    public static func info(_ text: String) -> String {
        wrap(text, code: "36")
    }

    // MARK: - Private

    private static func wrap(_ text: String, code: String) -> String {
        guard isEnabled else { return text }
        return "\u{1B}[\(code)m\(text)\u{1B}[0m"
    }
}
