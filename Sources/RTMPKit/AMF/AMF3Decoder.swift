// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors that can occur during AMF3 decoding.
public enum AMF3DecodingError: Error, Sendable {
    /// The input ended before a complete value could be read.
    case unexpectedEndOfData
    /// An unknown type marker was encountered.
    case unknownTypeMarker(UInt8)
    /// Invalid U29 variable-length encoding.
    case invalidU29Encoding
    /// Invalid UTF-8 string encoding.
    case invalidStringEncoding
    /// A reference index points beyond the reference table bounds.
    case invalidReferenceIndex(Int)
    /// Externalizable objects are not supported.
    case externalizableNotSupported
}

/// Decodes AMF3-encoded bytes into AMF3Value trees.
///
/// Each decoder instance maintains its own reference tables.
public struct AMF3Decoder: Sendable {
    private var refs = AMF3ReferenceTable()

    /// Creates a new AMF3 decoder.
    public init() {}

    /// Decode a single AMF3Value from the given bytes starting at offset.
    ///
    /// - Parameters:
    ///   - bytes: The input bytes.
    ///   - offset: The starting offset (default: 0).
    /// - Returns: A tuple of the decoded value and the number of bytes consumed.
    /// - Throws: ``AMF3DecodingError`` on invalid input.
    public mutating func decode(from bytes: [UInt8], offset: Int = 0) throws -> (AMF3Value, Int) {
        var pos = offset
        let value = try decodeValue(from: bytes, offset: &pos)
        return (value, pos - offset)
    }

    /// Decode all AMF3Values from a byte sequence.
    ///
    /// - Parameter bytes: The input bytes.
    /// - Returns: An array of all decoded values.
    /// - Throws: ``AMF3DecodingError`` on invalid input.
    public mutating func decodeAll(from bytes: [UInt8]) throws -> [AMF3Value] {
        var offset = 0
        var values: [AMF3Value] = []
        while offset < bytes.count {
            let value = try decodeValue(from: bytes, offset: &offset)
            values.append(value)
        }
        return values
    }

    /// Reset reference tables.
    public mutating func reset() {
        refs.reset()
    }

    // MARK: - Value Dispatch

    private mutating func decodeValue(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        guard offset < bytes.count else {
            throw AMF3DecodingError.unexpectedEndOfData
        }
        let marker = bytes[offset]
        offset += 1

        switch marker {
        case AMF3Value.Marker.undefined, AMF3Value.Marker.null,
            AMF3Value.Marker.false, AMF3Value.Marker.true:
            return decodeMarkerOnly(marker)
        case AMF3Value.Marker.integer: return try decodeInteger(from: bytes, offset: &offset)
        case AMF3Value.Marker.double: return try decodeDouble(from: bytes, offset: &offset)
        case AMF3Value.Marker.string: return try .string(decodeAMF3String(from: bytes, offset: &offset))
        case AMF3Value.Marker.xmlDocument, AMF3Value.Marker.xml:
            return try decodeXMLLike(from: bytes, offset: &offset, isXML: marker == AMF3Value.Marker.xml)
        default:
            return try decodeComplexValue(marker: marker, from: bytes, offset: &offset)
        }
    }

    private func decodeMarkerOnly(_ marker: UInt8) -> AMF3Value {
        switch marker {
        case AMF3Value.Marker.null: return .null
        case AMF3Value.Marker.false: return .false
        case AMF3Value.Marker.true: return .true
        default: return .undefined
        }
    }

    private mutating func decodeComplexValue(
        marker: UInt8, from bytes: [UInt8], offset: inout Int
    ) throws -> AMF3Value {
        switch marker {
        case AMF3Value.Marker.date: return try decodeDate(from: bytes, offset: &offset)
        case AMF3Value.Marker.array: return try decodeArray(from: bytes, offset: &offset)
        case AMF3Value.Marker.object: return try decodeObject(from: bytes, offset: &offset)
        case AMF3Value.Marker.byteArray: return try decodeByteArray(from: bytes, offset: &offset)
        case AMF3Value.Marker.vectorInt: return try decodeVectorInt(from: bytes, offset: &offset)
        case AMF3Value.Marker.vectorUInt: return try decodeVectorUInt(from: bytes, offset: &offset)
        case AMF3Value.Marker.vectorDouble: return try decodeVectorDouble(from: bytes, offset: &offset)
        case AMF3Value.Marker.vectorObject: return try decodeVectorObject(from: bytes, offset: &offset)
        case AMF3Value.Marker.dictionary: return try decodeDictionary(from: bytes, offset: &offset)
        default:
            throw AMF3DecodingError.unknownTypeMarker(marker)
        }
    }

    // MARK: - Integer

    private func decodeInteger(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        // Sign-extend from 29 bits
        let signed: Int32
        if u29 & 0x1000_0000 != 0 {
            signed = Int32(bitPattern: u29 | 0xE000_0000)
        } else {
            signed = Int32(u29)
        }
        return .integer(signed)
    }

    // MARK: - Double

    private func decodeDouble(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let bits = try readUInt64BE(from: bytes, offset: &offset)
        return .double(Double(bitPattern: bits))
    }

    // MARK: - String

    private mutating func decodeAMF3String(from bytes: [UInt8], offset: inout Int) throws -> String {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            // Reference
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.strings.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.strings[refIndex]
        }
        let length = Int(u29 >> 1)
        guard offset + length <= bytes.count else {
            throw AMF3DecodingError.unexpectedEndOfData
        }
        let slice = bytes[offset..<(offset + length)]
        offset += length
        let str = try decodeValidatedUTF8(slice)
        if !str.isEmpty {
            refs.addString(str)
        }
        return str
    }

    // MARK: - XML / XMLDocument

    private mutating func decodeXMLLike(
        from bytes: [UInt8], offset: inout Int, isXML: Bool
    ) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let length = Int(u29 >> 1)
        guard offset + length <= bytes.count else {
            throw AMF3DecodingError.unexpectedEndOfData
        }
        let slice = bytes[offset..<(offset + length)]
        offset += length
        let content = try decodeValidatedUTF8(slice)
        let value: AMF3Value = isXML ? .xml(content) : .xmlDocument(content)
        refs.addObject(value)
        return value
    }

    // MARK: - Date

    private mutating func decodeDate(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let bits = try readUInt64BE(from: bytes, offset: &offset)
        let value = AMF3Value.date(Double(bitPattern: bits))
        refs.addObject(value)
        return value
    }

    // MARK: - Array

    private mutating func decodeArray(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let denseCount = Int(u29 >> 1)
        // Placeholder: add to refs before decoding to handle circular refs
        let placeholder = AMF3Value.array(dense: [], associative: [:])
        let placeholderIndex = refs.objects.count
        refs.addObject(placeholder)

        // Associative part
        var associative: [String: AMF3Value] = [:]
        while true {
            let key = try decodeAMF3String(from: bytes, offset: &offset)
            if key.isEmpty { break }
            let val = try decodeValue(from: bytes, offset: &offset)
            associative[key] = val
        }
        // Dense part
        var dense: [AMF3Value] = []
        dense.reserveCapacity(min(denseCount, 1024))
        for _ in 0..<denseCount {
            let val = try decodeValue(from: bytes, offset: &offset)
            dense.append(val)
        }
        let result = AMF3Value.array(dense: dense, associative: associative)
        refs.replaceObject(at: placeholderIndex, with: result)
        return result
    }

    // MARK: - Object

    private mutating func decodeObject(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let traits = try decodeTraitsFromU29(u29, from: bytes, offset: &offset)
        guard !traits.isExternalizable else {
            throw AMF3DecodingError.externalizableNotSupported
        }

        // Placeholder
        let placeholder = AMF3Value.object(AMF3Object(traits: traits))
        let placeholderIndex = refs.objects.count
        refs.addObject(placeholder)

        // Sealed properties
        var sealed: [String: AMF3Value] = [:]
        for propName in traits.properties {
            sealed[propName] = try decodeValue(from: bytes, offset: &offset)
        }
        // Dynamic properties
        var dynamic: [String: AMF3Value] = [:]
        if traits.isDynamic {
            while true {
                let key = try decodeAMF3String(from: bytes, offset: &offset)
                if key.isEmpty { break }
                dynamic[key] = try decodeValue(from: bytes, offset: &offset)
            }
        }
        let obj = AMF3Object(traits: traits, sealedProperties: sealed, dynamicProperties: dynamic)
        let result = AMF3Value.object(obj)
        refs.replaceObject(at: placeholderIndex, with: result)
        return result
    }

    private mutating func decodeTraitsFromU29(
        _ u29: UInt32, from bytes: [UInt8], offset: inout Int
    ) throws -> AMF3Traits {
        if (u29 & 0x03) == 0x01 {
            // Traits reference
            let refIndex = Int(u29 >> 2)
            guard refIndex < refs.traits.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.traits[refIndex]
        }
        // Inline traits
        let isExternalizable = (u29 & 0x04) != 0
        let isDynamic = (u29 & 0x08) != 0
        let propCount = Int(u29 >> 4)
        let className = try decodeAMF3String(from: bytes, offset: &offset)
        var properties: [String] = []
        for _ in 0..<propCount {
            properties.append(try decodeAMF3String(from: bytes, offset: &offset))
        }
        let traits = AMF3Traits(
            className: className,
            isDynamic: isDynamic,
            isExternalizable: isExternalizable,
            properties: properties
        )
        refs.addTraits(traits)
        return traits
    }

    // MARK: - ByteArray

    private mutating func decodeByteArray(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let length = Int(u29 >> 1)
        guard offset + length <= bytes.count else {
            throw AMF3DecodingError.unexpectedEndOfData
        }
        let data = Array(bytes[offset..<(offset + length)])
        offset += length
        let value = AMF3Value.byteArray(data)
        refs.addObject(value)
        return value
    }

}

// MARK: - Vectors, Dictionary & Byte Helpers

extension AMF3Decoder {

    mutating func decodeVectorInt(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let count = Int(u29 >> 1)
        guard offset < bytes.count else { throw AMF3DecodingError.unexpectedEndOfData }
        let fixed = bytes[offset] != 0x00
        offset += 1
        var values: [Int32] = []
        values.reserveCapacity(min(count, 1024))
        for _ in 0..<count {
            let u = try readUInt32BE(from: bytes, offset: &offset)
            values.append(Int32(bitPattern: u))
        }
        let value = AMF3Value.vectorInt(values, fixed: fixed)
        refs.addObject(value)
        return value
    }

    mutating func decodeVectorUInt(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let count = Int(u29 >> 1)
        guard offset < bytes.count else { throw AMF3DecodingError.unexpectedEndOfData }
        let fixed = bytes[offset] != 0x00
        offset += 1
        var values: [UInt32] = []
        values.reserveCapacity(min(count, 1024))
        for _ in 0..<count {
            values.append(try readUInt32BE(from: bytes, offset: &offset))
        }
        let value = AMF3Value.vectorUInt(values, fixed: fixed)
        refs.addObject(value)
        return value
    }

    mutating func decodeVectorDouble(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let count = Int(u29 >> 1)
        guard offset < bytes.count else { throw AMF3DecodingError.unexpectedEndOfData }
        let fixed = bytes[offset] != 0x00
        offset += 1
        var values: [Double] = []
        values.reserveCapacity(min(count, 1024))
        for _ in 0..<count {
            let bits = try readUInt64BE(from: bytes, offset: &offset)
            values.append(Double(bitPattern: bits))
        }
        let value = AMF3Value.vectorDouble(values, fixed: fixed)
        refs.addObject(value)
        return value
    }

    mutating func decodeVectorObject(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let count = Int(u29 >> 1)
        guard offset < bytes.count else { throw AMF3DecodingError.unexpectedEndOfData }
        let fixed = bytes[offset] != 0x00
        offset += 1
        let typeName = try decodeAMF3String(from: bytes, offset: &offset)
        var values: [AMF3Value] = []
        values.reserveCapacity(min(count, 1024))
        for _ in 0..<count {
            values.append(try decodeValue(from: bytes, offset: &offset))
        }
        let value = AMF3Value.vectorObject(values, typeName: typeName, fixed: fixed)
        refs.addObject(value)
        return value
    }

    mutating func decodeDictionary(from bytes: [UInt8], offset: inout Int) throws -> AMF3Value {
        let u29 = try readU29(from: bytes, offset: &offset)
        if (u29 & 1) == 0 {
            let refIndex = Int(u29 >> 1)
            guard refIndex < refs.objects.count else {
                throw AMF3DecodingError.invalidReferenceIndex(refIndex)
            }
            return refs.objects[refIndex]
        }
        let count = Int(u29 >> 1)
        guard offset < bytes.count else { throw AMF3DecodingError.unexpectedEndOfData }
        let weakKeys = bytes[offset] != 0x00
        offset += 1
        var pairs: [(key: AMF3Value, value: AMF3Value)] = []
        pairs.reserveCapacity(min(count, 1024))
        for _ in 0..<count {
            let key = try decodeValue(from: bytes, offset: &offset)
            let val = try decodeValue(from: bytes, offset: &offset)
            pairs.append((key: key, value: val))
        }
        let value = AMF3Value.dictionary(pairs, weakKeys: weakKeys)
        refs.addObject(value)
        return value
    }

    // MARK: - U29 Reading

    func readU29(from bytes: [UInt8], offset: inout Int) throws -> UInt32 {
        guard offset < bytes.count else {
            throw AMF3DecodingError.unexpectedEndOfData
        }
        var result: UInt32 = 0
        // Up to 4 bytes
        for i in 0..<4 {
            guard offset < bytes.count else {
                throw AMF3DecodingError.unexpectedEndOfData
            }
            let byte = bytes[offset]
            offset += 1
            if i < 3 {
                result = (result << 7) | UInt32(byte & 0x7F)
                if byte & 0x80 == 0 { return result }
            } else {
                // 4th byte uses all 8 bits
                result = (result << 8) | UInt32(byte)
                return result
            }
        }
        throw AMF3DecodingError.invalidU29Encoding
    }

    // MARK: - Byte Reading

    func readUInt64BE(from bytes: [UInt8], offset: inout Int) throws -> UInt64 {
        guard offset + 8 <= bytes.count else {
            throw AMF3DecodingError.unexpectedEndOfData
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

    func readUInt32BE(from bytes: [UInt8], offset: inout Int) throws -> UInt32 {
        guard offset + 4 <= bytes.count else {
            throw AMF3DecodingError.unexpectedEndOfData
        }
        let value: UInt32 =
            UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
        offset += 4
        return value
    }

    // MARK: - UTF-8 Validation

    func decodeValidatedUTF8(_ bytes: ArraySlice<UInt8>) throws -> String {
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
                throw AMF3DecodingError.invalidStringEncoding
            }
        }
    }
}
