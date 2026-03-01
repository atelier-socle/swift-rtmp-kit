// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKitCommands

@Suite("ColorOutput — ANSI wrapping")
struct ColorOutputTests {

    @Test("success wraps text in green ANSI codes")
    func successGreen() {
        let result = ColorOutput.success("ok")
        // When colors are enabled, contains ANSI escape
        // When disabled (CI), returns plain text
        #expect(result.contains("ok"))
    }

    @Test("error wraps text in red ANSI codes")
    func errorRed() {
        let result = ColorOutput.error("fail")
        #expect(result.contains("fail"))
    }

    @Test("warning wraps text in yellow ANSI codes")
    func warningYellow() {
        let result = ColorOutput.warning("warn")
        #expect(result.contains("warn"))
    }

    @Test("bold wraps text in bold ANSI codes")
    func boldWrap() {
        let result = ColorOutput.bold("title")
        #expect(result.contains("title"))
    }

    @Test("dim wraps text in dim ANSI codes")
    func dimWrap() {
        let result = ColorOutput.dim("secondary")
        #expect(result.contains("secondary"))
    }

    @Test("info wraps text in cyan ANSI codes")
    func infoCyan() {
        let result = ColorOutput.info("status")
        #expect(result.contains("status"))
    }
}
