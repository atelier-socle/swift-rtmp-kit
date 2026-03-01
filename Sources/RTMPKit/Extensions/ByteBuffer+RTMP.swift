// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import NIOCore

extension ByteBuffer {
    // MARK: - 24-bit Integers (Big-Endian)

    /// Reads a 24-bit unsigned integer in big-endian byte order.
    ///
    /// - Returns: The decoded value, or `nil` if fewer than 3 bytes are readable.
    public mutating func readUInt24() -> UInt32? {
        guard readableBytes >= 3,
            let b0 = readInteger(as: UInt8.self),
            let b1 = readInteger(as: UInt8.self),
            let b2 = readInteger(as: UInt8.self)
        else { return nil }
        return UInt32(b0) << 16 | UInt32(b1) << 8 | UInt32(b2)
    }

    /// Writes a 24-bit unsigned integer in big-endian byte order.
    ///
    /// Only the lower 24 bits of `value` are written.
    ///
    /// - Parameter value: The value to write (masked to 24 bits).
    @discardableResult
    public mutating func writeUInt24(_ value: UInt32) -> Int {
        writeInteger(UInt8((value >> 16) & 0xFF))
            + writeInteger(UInt8((value >> 8) & 0xFF))
            + writeInteger(UInt8(value & 0xFF))
    }

    // MARK: - Little-Endian 32-bit (Message Stream ID Only)

    /// Reads a 32-bit unsigned integer in little-endian byte order.
    ///
    /// Used exclusively for RTMP message stream IDs, which are the only
    /// little-endian fields in the RTMP protocol.
    ///
    /// - Returns: The decoded value, or `nil` if fewer than 4 bytes are readable.
    public mutating func readUInt32LE() -> UInt32? {
        guard readableBytes >= 4,
            let b0 = readInteger(as: UInt8.self),
            let b1 = readInteger(as: UInt8.self),
            let b2 = readInteger(as: UInt8.self),
            let b3 = readInteger(as: UInt8.self)
        else { return nil }
        return UInt32(b0) | UInt32(b1) << 8 | UInt32(b2) << 16 | UInt32(b3) << 24
    }

    /// Writes a 32-bit unsigned integer in little-endian byte order.
    ///
    /// Used exclusively for RTMP message stream IDs.
    ///
    /// - Parameter value: The value to write.
    @discardableResult
    public mutating func writeUInt32LE(_ value: UInt32) -> Int {
        writeInteger(UInt8(value & 0xFF))
            + writeInteger(UInt8((value >> 8) & 0xFF))
            + writeInteger(UInt8((value >> 16) & 0xFF))
            + writeInteger(UInt8((value >> 24) & 0xFF))
    }
}
