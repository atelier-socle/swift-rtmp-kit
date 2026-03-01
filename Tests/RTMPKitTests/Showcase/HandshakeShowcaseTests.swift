// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("Handshake Showcase")
struct HandshakeShowcaseTests {

    @Test("Complete handshake lifecycle")
    func completeLifecycle() throws {
        var handshake = RTMPHandshake()
        #expect(handshake.state == .idle)

        // Step 1: Generate C0C1
        let c0c1 = try handshake.generateC0C1()
        #expect(c0c1.count == 1537)
        #expect(handshake.state == .sentC0C1)

        // Step 2: Simulate S0S1S2 response
        let s0: [UInt8] = [HandshakeBytes.version]
        let s1 = HandshakeBytes.generateC1(timestamp: 100)
        let c1 = Array(c0c1[1...])
        let s2 = HandshakeBytes.generateC2(fromS1: c1)
        let s0s1s2 = s0 + s1 + s2

        // Step 3: Process S0S1S2
        try handshake.processS0S1S2(s0s1s2)
        #expect(handshake.state == .receivedS0S1S2)

        // Step 4: Generate C2
        let c2 = try handshake.generateC2()
        #expect(c2.count == HandshakeBytes.packetSize)
        #expect(handshake.state == .complete)

        // Verify C2 echoes S1 random data
        let s1Random = HandshakeBytes.parseRandomData(from: s1)
        let c2Random = HandshakeBytes.parseRandomData(from: c2)
        #expect(c2Random == s1Random)
    }

    @Test("Handshake with version mismatch")
    func versionMismatch() throws {
        var handshake = RTMPHandshake()
        let c0c1 = try handshake.generateC0C1()
        let c1 = Array(c0c1[1...])

        // S0 with wrong version (4 instead of 3)
        let s0: [UInt8] = [0x04]
        let s1 = HandshakeBytes.generateC1()
        let s2 = HandshakeBytes.generateC2(fromS1: c1)
        let s0s1s2 = s0 + s1 + s2

        #expect(throws: RTMPHandshake.HandshakeError.self) {
            try handshake.processS0S1S2(s0s1s2)
        }
    }

    @Test("Handshake with corrupted S2")
    func corruptedS2() throws {
        var handshake = RTMPHandshake()
        let c0c1 = try handshake.generateC0C1()

        // S0 + S1 valid, S2 with wrong random data
        let s0: [UInt8] = [HandshakeBytes.version]
        let s1 = HandshakeBytes.generateC1()
        let corruptedS2 = Array(repeating: UInt8(0x00), count: HandshakeBytes.packetSize)
        let s0s1s2 = s0 + s1 + corruptedS2

        // processS0S1S2 should still succeed (validation is non-fatal)
        // but the handshake state reflects the validation result
        try handshake.processS0S1S2(s0s1s2)

        // C1 random data won't match S2 random data, but the
        // implementation may set state to failed or receivedS0S1S2
        let validStates: [RTMPHandshake.State] = [
            .receivedS0S1S2, .failed("S2 echo validation failed")
        ]
        #expect(validStates.contains(handshake.state))
    }

    @Test("C0C1 size is exactly 1537 bytes")
    func c0c1Size() throws {
        var handshake = RTMPHandshake()
        let c0c1 = try handshake.generateC0C1()
        // C0 = 1 byte (version), C1 = 1536 bytes
        #expect(c0c1.count == 1 + HandshakeBytes.packetSize)
    }

    @Test("C2 size is exactly 1536 bytes")
    func c2Size() throws {
        var handshake = RTMPHandshake()
        let c0c1 = try handshake.generateC0C1()
        let c1 = Array(c0c1[1...])
        let s0s1s2 =
            [HandshakeBytes.version]
            + HandshakeBytes.generateC1()
            + HandshakeBytes.generateC2(fromS1: c1)
        try handshake.processS0S1S2(s0s1s2)
        let c2 = try handshake.generateC2()
        #expect(c2.count == HandshakeBytes.packetSize)
    }

    @Test("State transitions are enforced")
    func stateTransitionsEnforced() {
        var handshake = RTMPHandshake()

        // Can't generate C2 from idle
        #expect(throws: RTMPHandshake.HandshakeError.self) {
            _ = try handshake.generateC2()
        }

        // Can't process S0S1S2 from idle
        let dummyData = Array(repeating: UInt8(0), count: 3073)
        #expect(throws: RTMPHandshake.HandshakeError.self) {
            try handshake.processS0S1S2(dummyData)
        }
    }

    @Test("Handshake bytes are random (non-zero)")
    func randomBytesNotAllZero() throws {
        var handshake = RTMPHandshake()
        let c0c1 = try handshake.generateC0C1()
        let c1 = Array(c0c1[1...])
        let randomSection = HandshakeBytes.parseRandomData(from: c1)
        // Extremely unlikely that 1528 random bytes are all zero
        #expect(randomSection.contains { $0 != 0 })
    }

    @Test("Timestamp fields are correctly positioned")
    func timestampFieldPosition() {
        let c1 = HandshakeBytes.generateC1(timestamp: 0x0102_0304)
        // Bytes [0..3] = timestamp (big-endian)
        let timestamp = HandshakeBytes.parseTimestamp(from: c1)
        #expect(timestamp == 0x0102_0304)
        // Bytes [4..7] = zero
        #expect(c1[4] == 0)
        #expect(c1[5] == 0)
        #expect(c1[6] == 0)
        #expect(c1[7] == 0)
        // Bytes [8..1535] = random (1528 bytes)
        let random = HandshakeBytes.parseRandomData(from: c1)
        #expect(random.count == HandshakeBytes.randomDataSize)
    }
}
