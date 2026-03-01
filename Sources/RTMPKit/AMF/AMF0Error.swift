// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors that can occur during AMF0 encoding or decoding.
public enum AMF0Error: Error, Sendable, Equatable {
    /// Unexpected end of data while decoding.
    case unexpectedEndOfData

    /// Unknown or unsupported type marker encountered.
    case unknownTypeMarker(UInt8)

    /// Invalid UTF-8 string data.
    case invalidUTF8String

    /// Reference index out of bounds.
    case invalidReference(index: UInt16, tableSize: Int)

    /// String too long for the encoding (> `UInt16.max` for String, > `UInt32.max` for LongString).
    case stringTooLong(length: Int)

    /// Nested object depth exceeded (prevents stack overflow from malicious data).
    case maxDepthExceeded(limit: Int)

    /// Reserved type marker encountered (MovieClip `0x04`, RecordSet `0x0E`).
    case reservedTypeMarker(UInt8)
}

// MARK: - CustomStringConvertible

extension AMF0Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unexpectedEndOfData:
            return "AMF0Error: unexpected end of data"
        case let .unknownTypeMarker(marker):
            return "AMF0Error: unknown type marker 0x\(String(marker, radix: 16, uppercase: true))"
        case .invalidUTF8String:
            return "AMF0Error: invalid UTF-8 string data"
        case let .invalidReference(index, tableSize):
            return "AMF0Error: reference index \(index) out of bounds (table size: \(tableSize))"
        case let .stringTooLong(length):
            return "AMF0Error: string too long (\(length) bytes)"
        case let .maxDepthExceeded(limit):
            return "AMF0Error: max nesting depth exceeded (limit: \(limit))"
        case let .reservedTypeMarker(marker):
            return "AMF0Error: reserved type marker 0x\(String(marker, radix: 16, uppercase: true))"
        }
    }
}
