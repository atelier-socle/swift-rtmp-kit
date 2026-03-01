// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// RTMP chunk stream ID with encoding/decoding support.
///
/// Chunk stream IDs (CSIDs) identify multiplexed channels within an RTMP
/// connection. The encoding uses 1, 2, or 3 bytes depending on the value:
/// - CSID 2–63: 1-byte form (value in the 6-bit field of the basic header)
/// - CSID 64–319: 2-byte form (basic header byte + 1 extra byte)
/// - CSID 320–65599: 3-byte form (basic header byte + 2 extra bytes)
///
/// CSIDs 0 and 1 are reserved as encoding markers and cannot be used as
/// actual stream IDs.
public struct ChunkStreamID: Sendable, Equatable, Hashable {
    /// The chunk stream ID value (2–65599).
    public let value: UInt32

    /// Creates a chunk stream ID.
    ///
    /// - Parameter value: The CSID value (must be 2–65599).
    public init(value: UInt32) {
        self.value = value
    }

    /// Protocol control messages (CSID 2).
    public static let protocolControl = ChunkStreamID(value: 2)

    /// Command messages such as `connect` and `createStream` (CSID 3).
    public static let command = ChunkStreamID(value: 3)

    /// Audio data (CSID 4).
    public static let audio = ChunkStreamID(value: 4)

    /// Video data (CSID 6).
    public static let video = ChunkStreamID(value: 6)

    /// Number of bytes needed to encode this CSID in the basic header.
    ///
    /// - CSID 2–63: 1 byte
    /// - CSID 64–319: 2 bytes
    /// - CSID 320–65599: 3 bytes
    public var encodedByteCount: Int {
        if value <= 63 {
            return 1
        } else if value <= 319 {
            return 2
        } else {
            return 3
        }
    }

    /// Whether this is a valid chunk stream ID (2–65599).
    public var isValid: Bool {
        value >= 2 && value <= 65599
    }

    /// Encodes this CSID into the basic header byte(s).
    ///
    /// The `fmt` parameter provides the 2-bit format value for the first byte.
    ///
    /// - Parameters:
    ///   - fmt: The chunk format (0–3).
    ///   - buffer: Destination byte buffer.
    public func encode(fmt: ChunkFormat, into buffer: inout [UInt8]) {
        let fmtBits = fmt.rawValue << 6
        if value >= 2 && value <= 63 {
            buffer.append(fmtBits | UInt8(value))
        } else if value >= 64 && value <= 319 {
            buffer.append(fmtBits | 0x00)
            buffer.append(UInt8(value - 64))
        } else {
            buffer.append(fmtBits | 0x01)
            let adjusted = value - 64
            buffer.append(UInt8(adjusted & 0xFF))
            buffer.append(UInt8((adjusted >> 8) & 0xFF))
        }
    }

    /// Decodes a chunk stream ID from the basic header byte(s).
    ///
    /// - Parameters:
    ///   - bytes: Source byte array.
    ///   - offset: Read position (advanced past the CSID bytes).
    /// - Returns: A tuple of (ChunkFormat, ChunkStreamID), or `nil` if
    ///   not enough bytes are available.
    public static func decode(
        from bytes: [UInt8],
        offset: inout Int
    ) -> (ChunkFormat, ChunkStreamID)? {
        guard offset < bytes.count else { return nil }
        let byte0 = bytes[offset]
        guard let fmt = ChunkFormat(rawValue: byte0 >> 6) else { return nil }
        let csidField = byte0 & 0x3F
        offset += 1
        switch csidField {
        case 0:
            guard offset < bytes.count else { return nil }
            let csid = UInt32(bytes[offset]) + 64
            offset += 1
            return (fmt, ChunkStreamID(value: csid))
        case 1:
            guard offset + 1 < bytes.count else { return nil }
            let csid = UInt32(bytes[offset + 1]) * 256 + UInt32(bytes[offset]) + 64
            offset += 2
            return (fmt, ChunkStreamID(value: csid))
        default:
            return (fmt, ChunkStreamID(value: UInt32(csidField)))
        }
    }
}

// MARK: - CustomStringConvertible

extension ChunkStreamID: CustomStringConvertible {
    public var description: String {
        "CSID(\(value))"
    }
}
