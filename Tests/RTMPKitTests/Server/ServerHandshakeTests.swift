// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ServerHandshake")
struct ServerHandshakeTests {

    /// Build a valid C0+C1 (1537 bytes).
    private func validC0C1() -> [UInt8] {
        var c0c1 = [UInt8](repeating: 0, count: 1 + 1536)
        c0c1[0] = 0x03  // C0 version
        // C1: timestamp(4) + zeros(4) + random(1528)
        for i in 9..<1537 {
            c0c1[i] = UInt8.random(in: 0...255)
        }
        return c0c1
    }

    @Test("buildResponse with valid C0 returns 3073-byte response")
    func validResponseSize() throws {
        let c0c1 = validC0C1()
        let (s0s1s2, _) = try ServerHandshake.buildResponse(c0c1: c0c1)
        #expect(s0s1s2.count == 3073)
    }

    @Test("response first byte is 0x03 (S0)")
    func s0VersionByte() throws {
        let c0c1 = validC0C1()
        let (s0s1s2, _) = try ServerHandshake.buildResponse(c0c1: c0c1)
        #expect(s0s1s2[0] == 0x03)
    }

    @Test("S1 bytes 4-7 are all zeros")
    func s1ZeroBytes() throws {
        let c0c1 = validC0C1()
        let (s0s1s2, _) = try ServerHandshake.buildResponse(c0c1: c0c1)
        // S1 starts at byte 1, bytes 4-7 of S1 are s0s1s2[5..8]
        #expect(s0s1s2[5] == 0x00)
        #expect(s0s1s2[6] == 0x00)
        #expect(s0s1s2[7] == 0x00)
        #expect(s0s1s2[8] == 0x00)
    }

    @Test("S2 echoes C1 random bytes")
    func s2EchoesC1() throws {
        let c0c1 = validC0C1()
        let c1 = Array(c0c1[1..<1537])
        let (s0s1s2, _) = try ServerHandshake.buildResponse(c0c1: c0c1)
        // S2 starts at byte 1 + 1536 = 1537
        let s2 = Array(s0s1s2[1537..<3073])
        #expect(s2 == c1)
    }

    @Test("buildResponse with C0 version != 0x03 throws invalidVersion")
    func invalidVersion() {
        var c0c1 = validC0C1()
        c0c1[0] = 0x04  // wrong version
        #expect(throws: ServerHandshake.HandshakeError.self) {
            _ = try ServerHandshake.buildResponse(c0c1: c0c1)
        }
    }

    @Test("validateC2 with correct echo: no throw")
    func validateC2Correct() throws {
        let c0c1 = validC0C1()
        let (_, s1Random) = try ServerHandshake.buildResponse(c0c1: c0c1)
        // Build a valid C2 that echoes S1
        let c2 = HandshakeBytes.generateC2(fromS1: s1Random)
        try ServerHandshake.validateC2(c2, s1Random: s1Random)
    }

    @Test("validateC2 with corrupted echo throws invalidC2Echo")
    func validateC2Corrupted() throws {
        let c0c1 = validC0C1()
        let (_, s1Random) = try ServerHandshake.buildResponse(c0c1: c0c1)
        var c2 = HandshakeBytes.generateC2(fromS1: s1Random)
        // Corrupt a random byte in the echo area
        c2[100] = c2[100] &+ 1
        #expect(throws: ServerHandshake.HandshakeError.self) {
            try ServerHandshake.validateC2(c2, s1Random: s1Random)
        }
    }

    @Test("handshake response total length: 1 + 1536 + 1536 = 3073")
    func totalResponseLength() throws {
        let c0c1 = validC0C1()
        let (s0s1s2, _) = try ServerHandshake.buildResponse(c0c1: c0c1)
        let expectedSize = 1 + HandshakeBytes.packetSize + HandshakeBytes.packetSize
        #expect(s0s1s2.count == expectedSize)
    }
}
