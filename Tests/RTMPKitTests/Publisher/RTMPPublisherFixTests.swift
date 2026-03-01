// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - ServerInfo Tests

@Suite("ServerInfo — Struct")
struct ServerInfoTests {

    @Test("default initializer has nil/empty values")
    func defaultInit() {
        let info = ServerInfo()
        #expect(info.version == nil)
        #expect(info.capabilities == nil)
        #expect(info.objectEncoding == nil)
        #expect(info.enhancedRTMP == false)
        #expect(info.negotiatedCodecs.isEmpty)
    }

    @Test("Equatable works for identical values")
    func equatable() {
        var a = ServerInfo()
        a.version = "FMS/5,0,17"
        a.capabilities = 31
        var b = ServerInfo()
        b.version = "FMS/5,0,17"
        b.capabilities = 31
        #expect(a == b)
    }

    @Test("Equatable detects differences")
    func notEqual() {
        var a = ServerInfo()
        a.enhancedRTMP = true
        let b = ServerInfo()
        #expect(a != b)
    }
}

// MARK: - StatusInfo Tests

@Suite("StatusInfo — Struct")
struct StatusInfoTests {

    @Test("default initializer has unknown/empty values")
    func defaultInit() {
        let info = StatusInfo()
        #expect(info.code == "unknown")
        #expect(info.level == "")
        #expect(info.description == "")
    }

    @Test("custom initializer stores values")
    func customInit() {
        let info = StatusInfo(
            code: "NetStream.Publish.Start",
            level: "status",
            description: "Publishing live"
        )
        #expect(info.code == "NetStream.Publish.Start")
        #expect(info.level == "status")
        #expect(info.description == "Publishing live")
    }

    @Test("Equatable works")
    func equatable() {
        let a = StatusInfo(code: "a", level: "b", description: "c")
        let b = StatusInfo(code: "a", level: "b", description: "c")
        #expect(a == b)
    }

    @Test("Equatable detects differences")
    func notEqual() {
        let a = StatusInfo(code: "a", level: "b", description: "c")
        let b = StatusInfo(code: "a", level: "b", description: "d")
        #expect(a != b)
    }
}

// MARK: - parseServerInfo Tests

@Suite("RTMPPublisher+Internal — parseServerInfo")
struct RTMPPublisherParseServerInfoTests {

    @Test("parses version and capabilities from properties")
    func parsesProperties() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let props: AMF0Value = .object([
            ("fmsVer", .string("FMS/5,0,17")),
            ("capabilities", .number(31))
        ])
        let result = await publisher.parseServerInfo(
            properties: props, info: nil
        )
        #expect(result.version == "FMS/5,0,17")
        #expect(result.capabilities == 31)
    }

    @Test("parses objectEncoding from info")
    func parsesInfoObject() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let info: AMF0Value = .object([
            ("objectEncoding", .number(0))
        ])
        let result = await publisher.parseServerInfo(
            properties: nil, info: info
        )
        #expect(result.objectEncoding == 0)
    }

    @Test("parses fourCcList from info for Enhanced RTMP")
    func parsesFourCcList() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let info: AMF0Value = .object([
            ("objectEncoding", .number(0)),
            (
                "fourCcList",
                .strictArray([
                    .string("av01"), .string("hvc1")
                ])
            )
        ])
        let result = await publisher.parseServerInfo(
            properties: nil, info: info
        )
        #expect(result.enhancedRTMP == true)
        #expect(result.negotiatedCodecs.count == 2)
    }

    @Test("returns empty ServerInfo for nil values")
    func nilValues() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let result = await publisher.parseServerInfo(
            properties: nil, info: nil
        )
        #expect(result == ServerInfo())
    }

    @Test("returns empty ServerInfo for non-object values")
    func nonObjectValues() async {
        let publisher = RTMPPublisher(transport: MockTransport())
        let result = await publisher.parseServerInfo(
            properties: .string("bad"), info: .number(42)
        )
        #expect(result == ServerInfo())
    }
}

// MARK: - Publish Rejection Tests

@Suite("RTMPPublisher+Internal — publish rejection")
struct RTMPPublisherPublishRejectionTests {

    @Test("BadName error onStatus rejects publish")
    func badNameRejects() async {
        let mock = MockTransport()
        mock.scriptedMessages = [
            RTMPMessage(
                command: .result(
                    transactionID: 1,
                    properties: nil,
                    information: .object([
                        ("code", .string("NetConnection.Connect.Success"))
                    ])
                )),
            RTMPMessage(
                command: .result(
                    transactionID: 4,
                    properties: nil,
                    information: .number(1)
                )),
            RTMPMessage(
                command: .onStatus(
                    information: .object([
                        ("code", .string("NetStream.Publish.BadName")),
                        ("level", .string("error")),
                        ("description", .string("Bad stream name"))
                    ])))
        ]
        let publisher = RTMPPublisher(transport: mock)
        do {
            try await publisher.publish(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
            Issue.record("Expected publishFailed error")
        } catch let error as RTMPError {
            if case .publishFailed(let code, _) = error {
                #expect(code == "NetStream.Publish.BadName")
            } else {
                Issue.record("Expected publishFailed, got \(error)")
            }
        } catch {
            // Any error is acceptable — the publisher didn't hang.
        }
    }

    @Test("error level onStatus for unknown code rejects publish")
    func unknownErrorLevelRejects() async {
        let mock = MockTransport()
        mock.scriptedMessages = [
            RTMPMessage(
                command: .result(
                    transactionID: 1,
                    properties: nil,
                    information: .object([
                        ("code", .string("NetConnection.Connect.Success"))
                    ])
                )),
            RTMPMessage(
                command: .result(
                    transactionID: 4,
                    properties: nil,
                    information: .number(1)
                )),
            RTMPMessage(
                command: .onStatus(
                    information: .object([
                        ("code", .string("Custom.Unknown.Error")),
                        ("level", .string("error")),
                        ("description", .string("Custom error"))
                    ])))
        ]
        let publisher = RTMPPublisher(transport: mock)
        do {
            try await publisher.publish(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
            Issue.record("Expected publishFailed error")
        } catch let error as RTMPError {
            if case .publishFailed(let code, _) = error {
                #expect(code == "Custom.Unknown.Error")
            } else {
                Issue.record("Expected publishFailed, got \(error)")
            }
        } catch {
            // Any error is acceptable.
        }
    }

    @Test("connect _result captures server info")
    func connectCapturesServerInfo() async throws {
        let mock = MockTransport()
        mock.scriptedMessages = [
            RTMPMessage(
                command: .result(
                    transactionID: 1,
                    properties: .object([
                        ("fmsVer", .string("FMS/5,0,17")),
                        ("capabilities", .number(31))
                    ]),
                    information: .object([
                        ("code", .string("NetConnection.Connect.Success")),
                        ("objectEncoding", .number(0))
                    ])
                )),
            RTMPMessage(
                command: .result(
                    transactionID: 4,
                    properties: nil,
                    information: .number(1)
                )),
            RTMPMessage(
                command: .onStatus(
                    information: .object([
                        ("code", .string("NetStream.Publish.Start")),
                        ("description", .string("Publishing"))
                    ])))
        ]
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        let info = await publisher.serverInfo
        #expect(info.version == "FMS/5,0,17")
        #expect(info.capabilities == 31)
        #expect(info.objectEncoding == 0)
        await publisher.disconnect()
    }

    @Test("connect _error throws connectRejected")
    func connectErrorThrowsRejected() async {
        let mock = MockTransport()
        mock.scriptedMessages = [
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
                        ("description", .string("auth failed"))
                    ])
                ))
        ]
        let publisher = RTMPPublisher(transport: mock)
        do {
            try await publisher.publish(
                url: "rtmp://localhost/app",
                streamKey: "test"
            )
            Issue.record("Expected connectRejected error")
        } catch let error as RTMPError {
            if case .connectRejected(let code, let desc) = error {
                #expect(code == "NetConnection.Connect.Rejected")
                #expect(desc == "auth failed")
            } else {
                Issue.record("Expected connectRejected, got \(error)")
            }
        } catch {
            // Any error is acceptable.
        }
    }

    @Test("connect with Enhanced RTMP fourCcList captures codecs")
    func connectWithEnhancedRTMP() async throws {
        let mock = MockTransport()
        mock.scriptedMessages = [
            RTMPMessage(
                command: .result(
                    transactionID: 1,
                    properties: .object([
                        ("fmsVer", .string("FMS/5,0,17")),
                        ("capabilities", .number(31))
                    ]),
                    information: .object([
                        (
                            "code",
                            .string("NetConnection.Connect.Success")
                        ),
                        (
                            "fourCcList",
                            .strictArray([
                                .string("av01"), .string("hvc1")
                            ])
                        )
                    ])
                )),
            RTMPMessage(
                command: .result(
                    transactionID: 4,
                    properties: nil,
                    information: .number(1)
                )),
            RTMPMessage(
                command: .onStatus(
                    information: .object([
                        ("code", .string("NetStream.Publish.Start")),
                        ("description", .string("Publishing"))
                    ])))
        ]
        let publisher = RTMPPublisher(transport: mock)
        try await publisher.publish(
            url: "rtmp://localhost/app",
            streamKey: "test"
        )
        let info = await publisher.serverInfo
        #expect(info.enhancedRTMP == true)
        #expect(info.negotiatedCodecs.count == 2)
        await publisher.disconnect()
    }
}
