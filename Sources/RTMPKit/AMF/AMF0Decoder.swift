// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Decodes AMF0 binary data to values.
///
/// The decoder deserializes `[UInt8]` byte arrays into ``AMF0Value`` instances
/// following the Adobe AMF0 specification. It maintains an internal cursor
/// that advances as values are read, and a reference table for resolving
/// object references.
///
/// ## Usage
///
/// ```swift
/// var decoder = AMF0Decoder()
/// let value = try decoder.decode(from: bytes)
/// ```
public struct AMF0Decoder: Sendable {
    /// Maximum nesting depth to prevent stack overflow from malicious data.
    public static let defaultMaxDepth = 32

    private var referenceTable: [AMF0Value] = []
    private var maxDepth: Int

    /// Creates a new AMF0 decoder.
    ///
    /// - Parameter maxDepth: Maximum nesting depth for objects and arrays.
    ///   Defaults to ``defaultMaxDepth`` (32).
    public init(maxDepth: Int = AMF0Decoder.defaultMaxDepth) {
        self.maxDepth = maxDepth
    }

    /// Decodes a single AMF0 value from binary data.
    ///
    /// - Parameter bytes: The binary data to decode.
    /// - Returns: The decoded AMF0 value.
    /// - Throws: ``AMF0Error`` if the data is malformed.
    public mutating func decode(from bytes: [UInt8]) throws -> AMF0Value {
        var offset = 0
        return try decodeValue(from: bytes, offset: &offset, depth: 0)
    }

    /// Decodes all AMF0 values from binary data.
    ///
    /// Reads values sequentially until all bytes are consumed.
    ///
    /// - Parameter bytes: The binary data to decode.
    /// - Returns: An array of decoded AMF0 values.
    /// - Throws: ``AMF0Error`` if the data is malformed.
    public mutating func decodeAll(from bytes: [UInt8]) throws -> [AMF0Value] {
        var offset = 0
        var values: [AMF0Value] = []
        while offset < bytes.count {
            let value = try decodeValue(from: bytes, offset: &offset, depth: 0)
            values.append(value)
        }
        return values
    }

    /// Resets the reference table for a new decoding context.
    public mutating func reset() {
        referenceTable.removeAll()
    }

    // MARK: - Private

    private mutating func decodeValue(
        from bytes: [UInt8],
        offset: inout Int,
        depth: Int
    ) throws -> AMF0Value {
        guard offset < bytes.count else {
            throw AMF0Error.unexpectedEndOfData
        }

        let marker = bytes[offset]
        offset += 1

        switch marker {
        case AMF0Value.Marker.number:
            return try decodeNumber(from: bytes, offset: &offset)
        case AMF0Value.Marker.boolean:
            return try decodeBoolean(from: bytes, offset: &offset)
        case AMF0Value.Marker.string:
            return try .string(decodeUTF8String(from: bytes, offset: &offset))
        case AMF0Value.Marker.null:
            return .null
        case AMF0Value.Marker.undefined:
            return .undefined
        case AMF0Value.Marker.unsupported:
            return .unsupported
        case AMF0Value.Marker.reference:
            return try decodeReference(from: bytes, offset: &offset)
        default:
            return try decodeContainerValue(marker: marker, from: bytes, offset: &offset, depth: depth)
        }
    }

    private mutating func decodeContainerValue(
        marker: UInt8,
        from bytes: [UInt8],
        offset: inout Int,
        depth: Int
    ) throws -> AMF0Value {
        switch marker {
        case AMF0Value.Marker.object:
            return try decodeObject(from: bytes, offset: &offset, depth: depth)
        case AMF0Value.Marker.ecmaArray:
            return try decodeECMAArray(from: bytes, offset: &offset, depth: depth)
        case AMF0Value.Marker.strictArray:
            return try decodeStrictArray(from: bytes, offset: &offset, depth: depth)
        case AMF0Value.Marker.date:
            return try decodeDate(from: bytes, offset: &offset)
        case AMF0Value.Marker.longString:
            return try .longString(decodeLongUTF8String(from: bytes, offset: &offset))
        case AMF0Value.Marker.xmlDocument:
            return try .xmlDocument(decodeLongUTF8String(from: bytes, offset: &offset))
        case AMF0Value.Marker.typedObject:
            return try decodeTypedObject(from: bytes, offset: &offset, depth: depth)
        case AMF0Value.Marker.movieClipReserved, AMF0Value.Marker.recordSetReserved:
            throw AMF0Error.reservedTypeMarker(marker)
        default:
            throw AMF0Error.unknownTypeMarker(marker)
        }
    }

    private func decodeNumber(
        from bytes: [UInt8],
        offset: inout Int
    ) throws -> AMF0Value {
        let bits = try readUInt64BE(from: bytes, offset: &offset)
        return .number(Double(bitPattern: bits))
    }

    private func decodeBoolean(
        from bytes: [UInt8],
        offset: inout Int
    ) throws -> AMF0Value {
        guard offset < bytes.count else {
            throw AMF0Error.unexpectedEndOfData
        }
        let value = bytes[offset] != 0x00
        offset += 1
        return .boolean(value)
    }

    private mutating func decodeObject(
        from bytes: [UInt8],
        offset: inout Int,
        depth: Int
    ) throws -> AMF0Value {
        guard depth < maxDepth else {
            throw AMF0Error.maxDepthExceeded(limit: maxDepth)
        }
        let pairs = try decodePairs(from: bytes, offset: &offset, depth: depth + 1)
        let value = AMF0Value.object(pairs)
        referenceTable.append(value)
        return value
    }

    private mutating func decodeReference(
        from bytes: [UInt8],
        offset: inout Int
    ) throws -> AMF0Value {
        let index = try readUInt16BE(from: bytes, offset: &offset)
        guard Int(index) < referenceTable.count else {
            throw AMF0Error.invalidReference(index: index, tableSize: referenceTable.count)
        }
        return referenceTable[Int(index)]
    }

    private mutating func decodeECMAArray(
        from bytes: [UInt8],
        offset: inout Int,
        depth: Int
    ) throws -> AMF0Value {
        guard depth < maxDepth else {
            throw AMF0Error.maxDepthExceeded(limit: maxDepth)
        }
        // Count is a hint only — read until end marker
        _ = try readUInt32BE(from: bytes, offset: &offset)
        let pairs = try decodePairs(from: bytes, offset: &offset, depth: depth + 1)
        let value = AMF0Value.ecmaArray(pairs)
        referenceTable.append(value)
        return value
    }

    private mutating func decodeStrictArray(
        from bytes: [UInt8],
        offset: inout Int,
        depth: Int
    ) throws -> AMF0Value {
        guard depth < maxDepth else {
            throw AMF0Error.maxDepthExceeded(limit: maxDepth)
        }
        let count = try readUInt32BE(from: bytes, offset: &offset)
        var values: [AMF0Value] = []
        values.reserveCapacity(min(Int(count), 1024))
        for _ in 0..<count {
            let value = try decodeValue(from: bytes, offset: &offset, depth: depth + 1)
            values.append(value)
        }
        return .strictArray(values)
    }

    private func decodeDate(
        from bytes: [UInt8],
        offset: inout Int
    ) throws -> AMF0Value {
        let bits = try readUInt64BE(from: bytes, offset: &offset)
        let ms = Double(bitPattern: bits)
        let tz = try readInt16BE(from: bytes, offset: &offset)
        return .date(ms, timeZoneOffset: tz)
    }

    private mutating func decodeTypedObject(
        from bytes: [UInt8],
        offset: inout Int,
        depth: Int
    ) throws -> AMF0Value {
        guard depth < maxDepth else {
            throw AMF0Error.maxDepthExceeded(limit: maxDepth)
        }
        let className = try decodeUTF8String(from: bytes, offset: &offset)
        let pairs = try decodePairs(from: bytes, offset: &offset, depth: depth + 1)
        let value = AMF0Value.typedObject(className: className, properties: pairs)
        referenceTable.append(value)
        return value
    }

    // MARK: - String Reading

    /// Reads a UTF-8 string with a uint16 BE length prefix (no type marker).
    private func decodeUTF8String(
        from bytes: [UInt8],
        offset: inout Int
    ) throws -> String {
        let length = Int(try readUInt16BE(from: bytes, offset: &offset))
        guard offset + length <= bytes.count else {
            throw AMF0Error.unexpectedEndOfData
        }
        let slice = bytes[offset..<(offset + length)]
        offset += length
        return try decodeValidatedUTF8(slice)
    }

    /// Reads a long UTF-8 string with a uint32 BE length prefix (no type marker).
    private func decodeLongUTF8String(
        from bytes: [UInt8],
        offset: inout Int
    ) throws -> String {
        let length = Int(try readUInt32BE(from: bytes, offset: &offset))
        guard offset + length <= bytes.count else {
            throw AMF0Error.unexpectedEndOfData
        }
        let slice = bytes[offset..<(offset + length)]
        offset += length
        return try decodeValidatedUTF8(slice)
    }

    /// Decodes a byte slice as validated UTF-8, throwing on invalid sequences.
    private func decodeValidatedUTF8(_ bytes: ArraySlice<UInt8>) throws -> String {
        var result = ""
        var iterator = bytes.makeIterator()
        var codec = UTF8()
        while true {
            switch codec.decode(&iterator) {
            case .scalarValue(let scalar):
                result.unicodeScalars.append(scalar)
            case .emptyInput:
                return result
            case .error:
                throw AMF0Error.invalidUTF8String
            }
        }
    }

    // MARK: - Key-Value Pair Reading

    /// Decodes key-value pairs until the object end marker (`0x00 0x00 0x09`).
    private mutating func decodePairs(
        from bytes: [UInt8],
        offset: inout Int,
        depth: Int
    ) throws -> [(String, AMF0Value)] {
        var pairs: [(String, AMF0Value)] = []
        while true {
            // Check for object end: empty key (0x00 0x00) followed by objectEnd (0x09)
            guard offset + 2 < bytes.count else {
                throw AMF0Error.unexpectedEndOfData
            }
            if bytes[offset] == 0x00 && bytes[offset + 1] == 0x00
                && bytes[offset + 2] == AMF0Value.Marker.objectEnd
            {
                offset += 3  // Consume the end marker
                break
            }
            let key = try decodeUTF8String(from: bytes, offset: &offset)
            let value = try decodeValue(from: bytes, offset: &offset, depth: depth)
            pairs.append((key, value))
        }
        return pairs
    }

    // MARK: - Byte Reading

    private func readUInt64BE(from bytes: [UInt8], offset: inout Int) throws -> UInt64 {
        guard offset + 8 <= bytes.count else {
            throw AMF0Error.unexpectedEndOfData
        }
        let value: UInt64 =
            UInt64(bytes[offset]) << 56
            | UInt64(bytes[offset + 1]) << 48
            | UInt64(bytes[offset + 2]) << 40
            | UInt64(bytes[offset + 3]) << 32
            | UInt64(bytes[offset + 4]) << 24
            | UInt64(bytes[offset + 5]) << 16
            | UInt64(bytes[offset + 6]) << 8
            | UInt64(bytes[offset + 7])
        offset += 8
        return value
    }

    private func readUInt32BE(from bytes: [UInt8], offset: inout Int) throws -> UInt32 {
        guard offset + 4 <= bytes.count else {
            throw AMF0Error.unexpectedEndOfData
        }
        let value: UInt32 =
            UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
        offset += 4
        return value
    }

    private func readUInt16BE(from bytes: [UInt8], offset: inout Int) throws -> UInt16 {
        guard offset + 2 <= bytes.count else {
            throw AMF0Error.unexpectedEndOfData
        }
        let value: UInt16 = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
        offset += 2
        return value
    }

    private func readInt16BE(from bytes: [UInt8], offset: inout Int) throws -> Int16 {
        let unsigned = try readUInt16BE(from: bytes, offset: &offset)
        return Int16(bitPattern: unsigned)
    }
}
