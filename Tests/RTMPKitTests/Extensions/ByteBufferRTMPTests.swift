// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore
import Testing

@testable import RTMPKit

@Suite("ByteBuffer+RTMP — UInt24")
struct ByteBufferUInt24Tests {

    @Test("Write and read UInt24 zero")
    func writeReadZero() {
        var buffer = ByteBufferAllocator().buffer(capacity: 3)
        buffer.writeUInt24(0)
        #expect(buffer.readableBytes == 3)
        #expect(buffer.readUInt24() == 0)
    }

    @Test("Write and read UInt24 max (0xFFFFFF)")
    func writeReadMax() {
        var buffer = ByteBufferAllocator().buffer(capacity: 3)
        buffer.writeUInt24(0xFFFFFF)
        #expect(buffer.readUInt24() == 0xFFFFFF)
    }

    @Test("Write and read UInt24 arbitrary value")
    func writeReadArbitrary() {
        var buffer = ByteBufferAllocator().buffer(capacity: 3)
        buffer.writeUInt24(0x123456)
        #expect(buffer.readUInt24() == 0x123456)
    }

    @Test("UInt24 is big-endian")
    func bigEndianByteOrder() {
        var buffer = ByteBufferAllocator().buffer(capacity: 3)
        buffer.writeUInt24(0x010203)
        let bytes = buffer.readBytes(length: 3)
        #expect(bytes == [0x01, 0x02, 0x03])
    }

    @Test("Read UInt24 from insufficient bytes returns nil")
    func insufficientBytesReturnsNil() {
        var buffer = ByteBufferAllocator().buffer(capacity: 2)
        buffer.writeInteger(UInt8(0x01))
        buffer.writeInteger(UInt8(0x02))
        #expect(buffer.readUInt24() == nil)
    }

    @Test("UInt24 masks to lower 24 bits on write")
    func masksHighBits() {
        var buffer = ByteBufferAllocator().buffer(capacity: 3)
        buffer.writeUInt24(0xFF_123456)
        #expect(buffer.readUInt24() == 0x123456)
    }
}

@Suite("ByteBuffer+RTMP — UInt32 Little-Endian")
struct ByteBufferUInt32LETests {

    @Test("Write and read UInt32LE zero")
    func writeReadZero() {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeUInt32LE(0)
        #expect(buffer.readableBytes == 4)
        #expect(buffer.readUInt32LE() == 0)
    }

    @Test("Write and read UInt32LE max")
    func writeReadMax() {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeUInt32LE(UInt32.max)
        #expect(buffer.readUInt32LE() == UInt32.max)
    }

    @Test("Write and read UInt32LE arbitrary value")
    func writeReadArbitrary() {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeUInt32LE(0x0403_0201)
        #expect(buffer.readUInt32LE() == 0x0403_0201)
    }

    @Test("UInt32LE byte order is little-endian")
    func littleEndianByteOrder() {
        var buffer = ByteBufferAllocator().buffer(capacity: 4)
        buffer.writeUInt32LE(0x0102_0304)
        let bytes = buffer.readBytes(length: 4)
        #expect(bytes == [0x04, 0x03, 0x02, 0x01])
    }

    @Test("Read UInt32LE from insufficient bytes returns nil")
    func insufficientBytesReturnsNil() {
        var buffer = ByteBufferAllocator().buffer(capacity: 3)
        buffer.writeInteger(UInt8(0x01))
        buffer.writeInteger(UInt8(0x02))
        buffer.writeInteger(UInt8(0x03))
        #expect(buffer.readUInt32LE() == nil)
    }
}
