// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPHandshake — State Machine")
struct RTMPHandshakeStateTests {

    // MARK: - Initial State

    @Test("Initial state is idle")
    func initialState() {
        let hs = RTMPHandshake()
        #expect(hs.state == .idle)
    }

    // MARK: - State Transitions

    @Test("generateC0C1 transitions to sentC0C1")
    func generateC0C1Transition() throws {
        var hs = RTMPHandshake()
        _ = try hs.generateC0C1()
        #expect(hs.state == .sentC0C1)
    }

    @Test("processS0S1S2 transitions to receivedS0S1S2")
    func processS0S1S2Transition() throws {
        var hs = RTMPHandshake()
        let c0c1 = try hs.generateC0C1()
        let c1 = Array(c0c1[1...])
        let s0s1s2 = buildMockS0S1S2(echoingC1: c1)
        try hs.processS0S1S2(s0s1s2)
        #expect(hs.state == .receivedS0S1S2)
    }

    @Test("generateC2 transitions to complete")
    func generateC2Transition() throws {
        var hs = RTMPHandshake()
        let c0c1 = try hs.generateC0C1()
        let c1 = Array(c0c1[1...])
        try hs.processS0S1S2(buildMockS0S1S2(echoingC1: c1))
        _ = try hs.generateC2()
        #expect(hs.state == .complete)
    }

    @Test("Full lifecycle: idle → sentC0C1 → receivedS0S1S2 → complete")
    func fullLifecycle() throws {
        var hs = RTMPHandshake()
        let c0c1 = try hs.generateC0C1()
        #expect(c0c1.count == 1537)
        #expect(c0c1[0] == 0x03)
        let c1 = Array(c0c1[1...])
        try hs.processS0S1S2(buildMockS0S1S2(echoingC1: c1))
        let c2 = try hs.generateC2()
        #expect(c2.count == 1536)
        #expect(hs.state == .complete)
    }

    // MARK: - Output Verification

    @Test("generateC0C1 returns 1537 bytes")
    func generateC0C1Size() throws {
        var hs = RTMPHandshake()
        let bytes = try hs.generateC0C1()
        #expect(bytes.count == 1537)
    }

    @Test("generateC0C1 first byte is 0x03")
    func generateC0C1Version() throws {
        var hs = RTMPHandshake()
        let bytes = try hs.generateC0C1()
        #expect(bytes[0] == 0x03)
    }

    @Test("generateC0C1 C1 bytes 4-7 are zeros")
    func generateC0C1ZeroBytes() throws {
        var hs = RTMPHandshake()
        let bytes = try hs.generateC0C1()
        #expect(bytes[5] == 0)
        #expect(bytes[6] == 0)
        #expect(bytes[7] == 0)
        #expect(bytes[8] == 0)
    }

    @Test("generateC2 returns 1536 bytes")
    func generateC2Size() throws {
        var hs = RTMPHandshake()
        let c0c1 = try hs.generateC0C1()
        let c1 = Array(c0c1[1...])
        try hs.processS0S1S2(buildMockS0S1S2(echoingC1: c1))
        let c2 = try hs.generateC2()
        #expect(c2.count == 1536)
    }

    @Test("generateC2 echoes S1 timestamp")
    func generateC2EchoesTimestamp() throws {
        var hs = RTMPHandshake()
        let c0c1 = try hs.generateC0C1()
        let c1 = Array(c0c1[1...])
        var s1 = [UInt8](repeating: 0, count: 1536)
        s1[0] = 0xAA
        s1[1] = 0xBB
        s1[2] = 0xCC
        s1[3] = 0xDD
        // Copy C1 random data into S2 for validation
        var s0s1s2: [UInt8] = [0x03]
        s0s1s2.append(contentsOf: s1)
        var s2 = [UInt8](repeating: 0, count: 1536)
        for i in 8..<1536 { s2[i] = c1[i] }
        s0s1s2.append(contentsOf: s2)
        try hs.processS0S1S2(s0s1s2)
        let c2 = try hs.generateC2()
        #expect(c2[0] == 0xAA)
        #expect(c2[1] == 0xBB)
        #expect(c2[2] == 0xCC)
        #expect(c2[3] == 0xDD)
    }

    @Test("generateC2 echoes S1 random data")
    func generateC2EchoesRandomData() throws {
        var hs = RTMPHandshake()
        let c0c1 = try hs.generateC0C1()
        let c1 = Array(c0c1[1...])
        let s1 = HandshakeBytes.generateC1(timestamp: 100)
        var s0s1s2: [UInt8] = [0x03]
        s0s1s2.append(contentsOf: s1)
        var s2 = [UInt8](repeating: 0, count: 1536)
        for i in 8..<1536 { s2[i] = c1[i] }
        s0s1s2.append(contentsOf: s2)
        try hs.processS0S1S2(s0s1s2)
        let c2 = try hs.generateC2()
        #expect(Array(c2[8..<1536]) == Array(s1[8..<1536]))
    }
}

@Suite("RTMPHandshake — Error Cases")
struct RTMPHandshakeErrorTests {

    // MARK: - Invalid State Transitions

    @Test("generateC0C1 when not idle throws")
    func generateC0C1NotIdle() throws {
        var hs = RTMPHandshake()
        _ = try hs.generateC0C1()
        #expect(throws: RTMPHandshake.HandshakeError.self) {
            try hs.generateC0C1()
        }
    }

    @Test("processS0S1S2 before generateC0C1 throws")
    func processBeforeGenerate() {
        var hs = RTMPHandshake()
        let data = [UInt8](repeating: 0x03, count: 3073)
        #expect(throws: RTMPHandshake.HandshakeError.self) {
            try hs.processS0S1S2(data)
        }
    }

    @Test("generateC2 before processS0S1S2 throws")
    func generateC2BeforeProcess() throws {
        var hs = RTMPHandshake()
        _ = try hs.generateC0C1()
        #expect(throws: RTMPHandshake.HandshakeError.self) {
            try hs.generateC2()
        }
    }

    @Test("generateC2 when idle throws")
    func generateC2WhenIdle() {
        var hs = RTMPHandshake()
        #expect(throws: RTMPHandshake.HandshakeError.self) {
            try hs.generateC2()
        }
    }

    // MARK: - Validation Errors

    @Test("processS0S1S2 rejects wrong version")
    func rejectWrongVersion() throws {
        var hs = RTMPHandshake()
        _ = try hs.generateC0C1()
        var data = [UInt8](repeating: 0, count: 3073)
        data[0] = 0x04  // Wrong version
        #expect(throws: RTMPHandshake.HandshakeError.self) {
            try hs.processS0S1S2(data)
        }
    }

    @Test("processS0S1S2 rejects wrong size")
    func rejectWrongSize() throws {
        var hs = RTMPHandshake()
        _ = try hs.generateC0C1()
        let data = [UInt8](repeating: 0x03, count: 100)
        #expect(throws: RTMPHandshake.HandshakeError.self) {
            try hs.processS0S1S2(data)
        }
    }

    @Test("processS0S1S2 rejects too-large packet")
    func rejectTooLarge() throws {
        var hs = RTMPHandshake()
        _ = try hs.generateC0C1()
        let data = [UInt8](repeating: 0x03, count: 5000)
        #expect(throws: RTMPHandshake.HandshakeError.self) {
            try hs.processS0S1S2(data)
        }
    }

    // MARK: - Reset

    @Test("Reset returns to idle")
    func resetToIdle() throws {
        var hs = RTMPHandshake()
        _ = try hs.generateC0C1()
        hs.reset()
        #expect(hs.state == .idle)
    }

    @Test("Reset allows new handshake")
    func resetAllowsNewHandshake() throws {
        var hs = RTMPHandshake()
        _ = try hs.generateC0C1()
        hs.reset()
        let bytes = try hs.generateC0C1()
        #expect(bytes.count == 1537)
        #expect(hs.state == .sentC0C1)
    }

    // MARK: - Helpers

    private func buildMockS0S1S2(echoingC1 c1: [UInt8]) -> [UInt8] {
        var result: [UInt8] = [0x03]  // S0
        result.append(contentsOf: [UInt8](repeating: 0, count: 1536))  // S1
        var s2 = [UInt8](repeating: 0, count: 1536)
        for i in 8..<min(1536, c1.count) { s2[i] = c1[i] }
        result.append(contentsOf: s2)
        return result
    }
}

// MARK: - Test Helpers

private func buildMockS0S1S2(echoingC1 c1: [UInt8]) -> [UInt8] {
    var result: [UInt8] = [0x03]  // S0
    result.append(contentsOf: [UInt8](repeating: 0, count: 1536))  // S1
    var s2 = [UInt8](repeating: 0, count: 1536)
    for i in 8..<min(1536, c1.count) { s2[i] = c1[i] }
    result.append(contentsOf: s2)
    return result
}
