// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("HandshakeBytes — Generation")
struct HandshakeBytesGenerationTests {

    // MARK: - Constants

    @Test("Packet size constant is 1536")
    func packetSizeConstant() {
        #expect(HandshakeBytes.packetSize == 1536)
    }

    @Test("Version constant is 0x03")
    func versionConstant() {
        #expect(HandshakeBytes.version == 0x03)
    }

    @Test("Random data size is 1528")
    func randomDataSizeConstant() {
        #expect(HandshakeBytes.randomDataSize == 1528)
    }

    // MARK: - C0 Generation

    @Test("generateC0 returns single byte 0x03")
    func generateC0() {
        let c0 = HandshakeBytes.generateC0()
        #expect(c0.count == 1)
        #expect(c0[0] == 0x03)
    }

    // MARK: - C1 Generation

    @Test("generateC1 returns 1536 bytes")
    func generateC1Size() {
        let c1 = HandshakeBytes.generateC1()
        #expect(c1.count == 1536)
    }

    @Test("generateC1 default timestamp is zero")
    func generateC1DefaultTimestamp() {
        let c1 = HandshakeBytes.generateC1()
        #expect(c1[0] == 0)
        #expect(c1[1] == 0)
        #expect(c1[2] == 0)
        #expect(c1[3] == 0)
    }

    @Test("generateC1 with timestamp encodes big-endian")
    func generateC1WithTimestamp() {
        let c1 = HandshakeBytes.generateC1(timestamp: 0x0102_0304)
        #expect(c1[0] == 0x01)
        #expect(c1[1] == 0x02)
        #expect(c1[2] == 0x03)
        #expect(c1[3] == 0x04)
    }

    @Test("generateC1 bytes 4-7 are zeros")
    func generateC1ZeroBytes() {
        let c1 = HandshakeBytes.generateC1()
        #expect(c1[4] == 0)
        #expect(c1[5] == 0)
        #expect(c1[6] == 0)
        #expect(c1[7] == 0)
    }

    @Test("generateC1 random data is not all zeros (probabilistic)")
    func generateC1RandomData() {
        let c1 = HandshakeBytes.generateC1()
        let randomSlice = c1[8..<1536]
        let hasNonZero = randomSlice.contains { $0 != 0 }
        #expect(hasNonZero)
    }

    // MARK: - C2 Generation

    @Test("generateC2 returns 1536 bytes")
    func generateC2Size() {
        let s1 = HandshakeBytes.generateC1()
        let c2 = HandshakeBytes.generateC2(fromS1: s1)
        #expect(c2.count == 1536)
    }

    @Test("generateC2 echoes S1 timestamp")
    func generateC2EchoesTimestamp() {
        let s1 = HandshakeBytes.generateC1(timestamp: 0xAABB_CCDD)
        let c2 = HandshakeBytes.generateC2(fromS1: s1)
        #expect(c2[0] == 0xAA)
        #expect(c2[1] == 0xBB)
        #expect(c2[2] == 0xCC)
        #expect(c2[3] == 0xDD)
    }

    @Test("generateC2 includes read timestamp")
    func generateC2ReadTimestamp() {
        let s1 = HandshakeBytes.generateC1()
        let c2 = HandshakeBytes.generateC2(fromS1: s1, readTimestamp: 0x1122_3344)
        #expect(c2[4] == 0x11)
        #expect(c2[5] == 0x22)
        #expect(c2[6] == 0x33)
        #expect(c2[7] == 0x44)
    }

    @Test("generateC2 echoes S1 random data")
    func generateC2EchoesRandomData() {
        let s1 = HandshakeBytes.generateC1()
        let c2 = HandshakeBytes.generateC2(fromS1: s1)
        #expect(Array(c2[8..<1536]) == Array(s1[8..<1536]))
    }
}

@Suite("HandshakeBytes — Parsing")
struct HandshakeBytesParsingTests {

    @Test("parseTimestamp from known bytes")
    func parseTimestamp() {
        var packet = [UInt8](repeating: 0, count: 1536)
        packet[0] = 0x01
        packet[1] = 0x02
        packet[2] = 0x03
        packet[3] = 0x04
        #expect(HandshakeBytes.parseTimestamp(from: packet) == 0x0102_0304)
    }

    @Test("parseTimestamp from short packet returns 0")
    func parseTimestampShort() {
        #expect(HandshakeBytes.parseTimestamp(from: [0x01, 0x02]) == 0)
    }

    @Test("parseRandomData extracts bytes 8-1535")
    func parseRandomData() {
        var packet = [UInt8](repeating: 0xAA, count: 1536)
        for i in 0..<8 { packet[i] = 0x00 }
        let random = HandshakeBytes.parseRandomData(from: packet)
        #expect(random.count == 1528)
        #expect(random.allSatisfy { $0 == 0xAA })
    }

    @Test("parseRandomData from short packet returns empty")
    func parseRandomDataShort() {
        let random = HandshakeBytes.parseRandomData(from: [0x01])
        #expect(random.isEmpty)
    }

    @Test("parseTimestamp zero")
    func parseTimestampZero() {
        let packet = [UInt8](repeating: 0, count: 1536)
        #expect(HandshakeBytes.parseTimestamp(from: packet) == 0)
    }

    @Test("parseTimestamp max value")
    func parseTimestampMax() {
        var packet = [UInt8](repeating: 0, count: 1536)
        packet[0] = 0xFF
        packet[1] = 0xFF
        packet[2] = 0xFF
        packet[3] = 0xFF
        #expect(HandshakeBytes.parseTimestamp(from: packet) == 0xFFFF_FFFF)
    }
}
