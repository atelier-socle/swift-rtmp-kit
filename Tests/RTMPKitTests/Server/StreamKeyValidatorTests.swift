// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("StreamKeyValidator — AllowAll")
struct AllowAllStreamKeyValidatorTests {

    @Test("AllowAllStreamKeyValidator always returns true")
    func alwaysValid() async {
        let validator = AllowAllStreamKeyValidator()
        let result = await validator.isValid(
            streamKey: "any_key", app: "live"
        )
        #expect(result)
    }

    @Test("AllowAll accepts empty key")
    func emptyKey() async {
        let validator = AllowAllStreamKeyValidator()
        let result = await validator.isValid(streamKey: "", app: "")
        #expect(result)
    }
}

@Suite("StreamKeyValidator — AllowList")
struct AllowListStreamKeyValidatorTests {

    @Test("AllowList returns true for key in allow-list")
    func validKey() async {
        let validator = AllowListStreamKeyValidator(
            allowedKeys: ["key_abc", "key_xyz"]
        )
        let result = await validator.isValid(
            streamKey: "key_abc", app: "live"
        )
        #expect(result)
    }

    @Test("AllowList returns false for key not in list")
    func invalidKey() async {
        let validator = AllowListStreamKeyValidator(
            allowedKeys: ["key_abc", "key_xyz"]
        )
        let result = await validator.isValid(
            streamKey: "unknown_key", app: "live"
        )
        #expect(!result)
    }

    @Test("AllowList is case-sensitive")
    func caseSensitive() async {
        let validator = AllowListStreamKeyValidator(
            allowedKeys: ["Live_Key"]
        )
        let lower = await validator.isValid(
            streamKey: "live_key", app: "live"
        )
        let exact = await validator.isValid(
            streamKey: "Live_Key", app: "live"
        )
        #expect(!lower)
        #expect(exact)
    }
}

@Suite("StreamKeyValidator — Closure")
struct ClosureStreamKeyValidatorTests {

    @Test("Closure validator calls the provided closure")
    func callsClosure() async {
        let validator = ClosureStreamKeyValidator { key, _ in
            key == "expected_key"
        }
        let result = await validator.isValid(
            streamKey: "expected_key", app: "live"
        )
        #expect(result)
        let wrongResult = await validator.isValid(
            streamKey: "other", app: "live"
        )
        #expect(!wrongResult)
    }

    @Test("Closure validator returns false when closure returns false")
    func closureReturnsFalse() async {
        let validator = ClosureStreamKeyValidator { key, app in
            key.hasPrefix("live_") && app == "live"
        }
        let valid = await validator.isValid(
            streamKey: "live_abc", app: "live"
        )
        let invalid = await validator.isValid(
            streamKey: "live_abc", app: "vod"
        )
        #expect(valid)
        #expect(!invalid)
    }
}

@Suite("StreamKeyValidator — Server Integration")
struct StreamKeyValidatorServerTests {

    private func makeClientScript(
        app: String = "live",
        streamName: String = "test_key"
    ) -> [RTMPMessage] {
        [
            RTMPMessage(
                command: .connect(
                    transactionID: 1,
                    properties: ConnectProperties(
                        app: app, tcUrl: "rtmp://localhost/\(app)"
                    )
                )
            ),
            RTMPMessage(
                command: .releaseStream(
                    transactionID: 2, streamName: streamName
                )
            ),
            RTMPMessage(
                command: .fcPublish(
                    transactionID: 3, streamName: streamName
                )
            ),
            RTMPMessage(
                command: .createStream(transactionID: 4)
            ),
            RTMPMessage(
                command: .publish(
                    transactionID: 5, streamName: streamName,
                    publishType: "live"
                )
            )
        ]
    }

    @Test("Invalid stream key prevents publishing")
    func invalidKeyRejectsPublish() async throws {
        let config = RTMPServerConfiguration(
            host: "127.0.0.1",
            streamKeyValidator: AllowListStreamKeyValidator(
                allowedKeys: ["valid_key"]
            )
        )
        let messages = makeClientScript(streamName: "invalid_key")
        let server = RTMPServer(
            configuration: config,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: true,
                    connected: true
                )
            }
        )
        try await server.start()
        let session = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let state = await session.state
        #expect(state != .publishing)
        await server.stop()
    }

    @Test("Valid stream key allows publishing")
    func validKeyAllowsPublish() async throws {
        let config = RTMPServerConfiguration(
            host: "127.0.0.1",
            streamKeyValidator: AllowListStreamKeyValidator(
                allowedKeys: ["valid_key"]
            )
        )
        let messages = makeClientScript(streamName: "valid_key")
        let server = RTMPServer(
            configuration: config,
            sessionTransportFactory: {
                MockTransport(
                    messages: messages,
                    suspendAfterMessages: true,
                    connected: true
                )
            }
        )
        try await server.start()
        let session = await server.acceptConnection()
        try await Task.sleep(for: .milliseconds(100))

        let state = await session.state
        #expect(state == .publishing)
        await server.stop()
    }
}
