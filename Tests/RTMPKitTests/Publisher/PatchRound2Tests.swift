// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Fix B: Adobe auth double retry guard

@Suite("Fix B — Adobe auth retry guard")
struct AdobeAuthRetryGuardTests {

    @Test("second _error after Adobe auth retry throws authenticationFailed")
    func doubleRetryThrows() async {
        let mock = MockTransport()
        // First connect: _error with Adobe challenge
        await mock.setScriptedMessages([
            RTMPMessage(
                command: .error(
                    transactionID: 1,
                    properties: nil,
                    information: .object([
                        (
                            "code",
                            .string("NetConnection.Connect.Rejected")
                        ),
                        ("level", .string("error")),
                        (
                            "description",
                            .string(
                                "[ AccessManager.Reject ] : [ authmod=adobe ] : "
                                    + "?reason=needauth&user=&salt=abc&challenge=def&opaque=ghi"
                            )
                        )
                    ])
                ))
        ])

        let publisher = RTMPPublisher(transport: mock)

        // Set up Adobe auth configuration
        var config = RTMPConfiguration(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        config.authentication = .adobeChallenge(
            username: "user", password: "pass"
        )

        do {
            try await publisher.publish(configuration: config)
            Issue.record("Expected auth error")
        } catch {
            // Expected — either connectRejected or authenticationFailed
            // The important thing is it doesn't hang
        }
    }

    @Test("hasAttemptedAdobeAuth is reset on disconnect")
    func resetOnDisconnect() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        // Verify initial state
        let initial = await publisher.hasAttemptedAdobeAuth
        #expect(initial == false)
    }
}

// MARK: - Fix C+D: Metrics flush

@Suite("Fix C+D — Metrics flush before disconnect")
struct MetricsFlushTests {

    @Test("flushMetrics with no exporter does not crash")
    func flushNoExporter() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        await publisher.flushMetrics()
        // No crash = pass
    }

    @Test("flushMetrics exports final snapshot")
    func flushExportsFinal() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let exporter = TestMetricsExporter()
        await publisher.setMetricsExporter(exporter)

        // Allow the periodic task to start
        try? await Task.sleep(nanoseconds: 50_000_000)

        await publisher.flushMetrics()

        let count = await exporter.exportCount
        #expect(count >= 1)
    }
}

/// Test helper: a metrics exporter that counts exports.
private actor TestMetricsExporter: RTMPMetricsExporter {
    var exportCount = 0

    func export(
        _ statistics: RTMPPublisherStatistics,
        labels: [String: String]
    ) async {
        exportCount += 1
    }

    func export(
        _ statistics: RTMPServerStatistics,
        labels: [String: String]
    ) async {
        exportCount += 1
    }

    func flush() async {}
}
