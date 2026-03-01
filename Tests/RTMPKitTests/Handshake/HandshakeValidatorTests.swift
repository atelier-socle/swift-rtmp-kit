// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("HandshakeValidator")
struct HandshakeValidatorTests {

    // MARK: - Version Validation

    @Test("validateVersion 0x03 returns true")
    func validVersion() {
        #expect(HandshakeValidator.validateVersion(0x03))
    }

    @Test("validateVersion 0x00 returns false")
    func invalidVersion0() {
        #expect(!HandshakeValidator.validateVersion(0x00))
    }

    @Test("validateVersion 0x04 returns false")
    func invalidVersion4() {
        #expect(!HandshakeValidator.validateVersion(0x04))
    }

    @Test("validateVersion 0xFF returns false")
    func invalidVersionFF() {
        #expect(!HandshakeValidator.validateVersion(0xFF))
    }

    @Test("validateVersion 0x02 returns false")
    func invalidVersion2() {
        #expect(!HandshakeValidator.validateVersion(0x02))
    }

    // MARK: - Packet Size Validation

    @Test("validatePacketSize 1536 returns true")
    func validPacketSize() {
        let packet = [UInt8](repeating: 0, count: 1536)
        #expect(HandshakeValidator.validatePacketSize(packet))
    }

    @Test("validatePacketSize 0 returns false")
    func emptyPacket() {
        #expect(!HandshakeValidator.validatePacketSize([]))
    }

    @Test("validatePacketSize 100 returns false")
    func shortPacket() {
        let packet = [UInt8](repeating: 0, count: 100)
        #expect(!HandshakeValidator.validatePacketSize(packet))
    }

    @Test("validatePacketSize 1535 returns false")
    func oneByteShort() {
        let packet = [UInt8](repeating: 0, count: 1535)
        #expect(!HandshakeValidator.validatePacketSize(packet))
    }

    @Test("validatePacketSize 1537 returns false")
    func oneByteOver() {
        let packet = [UInt8](repeating: 0, count: 1537)
        #expect(!HandshakeValidator.validatePacketSize(packet))
    }

    // MARK: - S2 Validation

    @Test("validateS2 matching random data returns true")
    func validS2() {
        let c1 = HandshakeBytes.generateC1()
        var s2 = [UInt8](repeating: 0, count: 1536)
        // Echo C1 random data into S2 bytes 8-1535
        for i in 8..<1536 {
            s2[i] = c1[i]
        }
        #expect(HandshakeValidator.validateS2(s2: s2, c1: c1))
    }

    @Test("validateS2 different random data returns false")
    func invalidS2DifferentData() {
        let c1 = HandshakeBytes.generateC1()
        var s2 = [UInt8](repeating: 0, count: 1536)
        // Different random data
        for i in 8..<1536 {
            s2[i] = UInt8(i & 0xFF)
        }
        // Only matches if by chance c1[8..] happens to be [8,9,...] which is astronomically unlikely
        let randomMatch = Array(s2[8..<1536]) == Array(c1[8..<1536])
        if !randomMatch {
            #expect(!HandshakeValidator.validateS2(s2: s2, c1: c1))
        }
    }

    @Test("validateS2 wrong S2 size returns false")
    func invalidS2WrongSize() {
        let c1 = HandshakeBytes.generateC1()
        let s2 = [UInt8](repeating: 0, count: 100)
        #expect(!HandshakeValidator.validateS2(s2: s2, c1: c1))
    }

    @Test("validateS2 wrong C1 size returns false")
    func invalidS2WrongC1Size() {
        let s2 = [UInt8](repeating: 0, count: 1536)
        let c1 = [UInt8](repeating: 0, count: 100)
        #expect(!HandshakeValidator.validateS2(s2: s2, c1: c1))
    }

    @Test("Full validation cycle: C1 → mock S2 → validates")
    func fullValidationCycle() {
        let c1 = HandshakeBytes.generateC1(timestamp: 42)
        // Build a proper S2 that echoes C1
        let s2 = HandshakeBytes.generateC2(fromS1: c1)
        // S2 bytes 8-1535 should match C1 bytes 8-1535
        #expect(HandshakeValidator.validateS2(s2: s2, c1: c1))
    }

    @Test("validateS2 allows different timestamps")
    func s2DifferentTimestampsOK() {
        let c1 = HandshakeBytes.generateC1(timestamp: 100)
        var s2 = [UInt8](repeating: 0, count: 1536)
        // Different timestamp in S2 (bytes 0-7)
        s2[0] = 0xFF
        s2[4] = 0xFF
        // But echo the random data
        for i in 8..<1536 {
            s2[i] = c1[i]
        }
        #expect(HandshakeValidator.validateS2(s2: s2, c1: c1))
    }
}
