// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// 24-bit unsigned integer helper for RTMP chunk headers.
///
/// RTMP uses 24-bit big-endian integers extensively for timestamps and
/// message lengths. This enum provides encoding/decoding utilities.
public enum UInt24 {
    /// Maximum value representable in 24 bits (`0xFFFFFF` = 16,777,215).
    public static let max: UInt32 = 0xFF_FFFF

    /// Reads a 24-bit big-endian unsigned integer from a byte array.
    ///
    /// - Parameters:
    ///   - bytes: Source byte array.
    ///   - offset: Read position (advanced by 3 on success).
    /// - Returns: The decoded value, or `nil` if not enough bytes remain.
    public static func read(from bytes: [UInt8], offset: inout Int) -> UInt32? {
        guard offset + 3 <= bytes.count else { return nil }
        let value =
            UInt32(bytes[offset]) << 16
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2])
        offset += 3
        return value
    }

    /// Writes a 24-bit big-endian unsigned integer to a byte buffer.
    ///
    /// Only the lower 24 bits of `value` are written.
    ///
    /// - Parameters:
    ///   - value: The value to write (masked to 24 bits).
    ///   - buffer: Destination byte buffer.
    public static func write(_ value: UInt32, to buffer: inout [UInt8]) {
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8(value & 0xFF))
    }
}
