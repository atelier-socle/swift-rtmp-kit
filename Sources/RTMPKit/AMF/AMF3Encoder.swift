// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors that can occur during AMF3 encoding.
public enum AMF3EncodingError: Error, Sendable {
    /// The integer value is outside the valid 29-bit range.
    case integerOutOfRange(Int32)
    /// Externalizable objects are not supported.
    case externalizableNotSupported
}

/// Encodes AMF3Value trees into bytes according to the Adobe AMF3 specification.
///
/// Each encoder instance maintains its own reference tables — do not reuse
/// across independent AMF3 messages.
public struct AMF3Encoder: Sendable {
    private var refs = AMF3ReferenceTable()

    /// Creates a new AMF3 encoder.
    public init() {}

    /// Encode a single AMF3Value.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: The encoded bytes.
    /// - Throws: ``AMF3EncodingError`` on encoding failures.
    public mutating func encode(_ value: AMF3Value) throws -> [UInt8] {
        var buffer: [UInt8] = []
        try encodeValue(value, into: &buffer)
        return buffer
    }

    /// Encode multiple values in sequence (for RTMP command messages).
    ///
    /// - Parameter values: The values to encode.
    /// - Returns: The concatenated encoded bytes.
    /// - Throws: ``AMF3EncodingError`` on encoding failures.
    public mutating func encodeAll(_ values: [AMF3Value]) throws -> [UInt8] {
        var buffer: [UInt8] = []
        for value in values {
            try encodeValue(value, into: &buffer)
        }
        return buffer
    }

    /// Reset reference tables (call between independent messages if reusing encoder).
    public mutating func reset() {
        refs.reset()
    }

    // MARK: - Value Dispatch

    private mutating func encodeValue(_ value: AMF3Value, into buf: inout [UInt8]) throws {
        switch value {
        case .undefined:
            buf.append(AMF3Value.Marker.undefined)
        case .null:
            buf.append(AMF3Value.Marker.null)
        case .false:
            buf.append(AMF3Value.Marker.false)
        case .true:
            buf.append(AMF3Value.Marker.true)
        case let .integer(v):
            try encodeInteger(v, into: &buf)
        case let .double(v):
            encodeDouble(v, into: &buf)
        case let .string(v):
            buf.append(AMF3Value.Marker.string)
            encodeAMF3String(v, into: &buf)
        case let .xmlDocument(v):
            try encodeXMLLike(marker: AMF3Value.Marker.xmlDocument, content: v, value: value, into: &buf)
        case let .xml(v):
            try encodeXMLLike(marker: AMF3Value.Marker.xml, content: v, value: value, into: &buf)
        default:
            try encodeComplexValue(value, into: &buf)
        }
    }

    private mutating func encodeComplexValue(_ value: AMF3Value, into buf: inout [UInt8]) throws {
        switch value {
        case let .date(ms):
            try encodeDate(ms, value: value, into: &buf)
        case let .array(dense, associative):
            try encodeArray(dense: dense, associative: associative, value: value, into: &buf)
        case let .object(obj):
            try encodeObject(obj, value: value, into: &buf)
        case let .byteArray(bytes):
            try encodeByteArray(bytes, value: value, into: &buf)
        case let .vectorInt(values, fixed):
            try encodeVectorInt(values, fixed: fixed, value: value, into: &buf)
        case let .vectorUInt(values, fixed):
            try encodeVectorUInt(values, fixed: fixed, value: value, into: &buf)
        case let .vectorDouble(values, fixed):
            try encodeVectorDouble(values, fixed: fixed, value: value, into: &buf)
        case let .vectorObject(values, typeName, fixed):
            try encodeVectorObject(values, typeName: typeName, fixed: fixed, value: value, into: &buf)
        case let .dictionary(pairs, weakKeys):
            try encodeDictionary(pairs, weakKeys: weakKeys, value: value, into: &buf)
        default:
            break
        }
    }

    // MARK: - Integer

    private func encodeInteger(_ value: Int32, into buf: inout [UInt8]) throws {
        guard value >= -268_435_456 && value <= 268_435_455 else {
            throw AMF3EncodingError.integerOutOfRange(value)
        }
        buf.append(AMF3Value.Marker.integer)
        // Convert to U29 representation (29-bit unsigned)
        let u29 = UInt32(bitPattern: value) & 0x1FFF_FFFF
        appendU29(u29, to: &buf)
    }

    // MARK: - Double

    private func encodeDouble(_ value: Double, into buf: inout [UInt8]) {
        buf.append(AMF3Value.Marker.double)
        appendDoubleBE(value, to: &buf)
    }

    // MARK: - String

    private mutating func encodeAMF3String(_ value: String, into buf: inout [UInt8]) {
        if value.isEmpty {
            appendU29(0x01, to: &buf)  // empty string marker, no reference
            return
        }
        if let refIndex = refs.stringReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)  // reference flag
            return
        }
        refs.addString(value)
        let utf8 = Array(value.utf8)
        appendU29((UInt32(utf8.count) << 1) | 1, to: &buf)  // inline flag
        buf.append(contentsOf: utf8)
    }

    // MARK: - XML / XMLDocument

    private mutating func encodeXMLLike(
        marker: UInt8, content: String, value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        buf.append(marker)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        let utf8 = Array(content.utf8)
        appendU29((UInt32(utf8.count) << 1) | 1, to: &buf)
        buf.append(contentsOf: utf8)
    }

    // MARK: - Date

    private mutating func encodeDate(
        _ ms: Double, value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        buf.append(AMF3Value.Marker.date)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        appendU29(0x01, to: &buf)  // inline flag (no reference)
        appendDoubleBE(ms, to: &buf)
    }

    // MARK: - Array

    private mutating func encodeArray(
        dense: [AMF3Value], associative: [String: AMF3Value],
        value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        buf.append(AMF3Value.Marker.array)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        appendU29((UInt32(dense.count) << 1) | 1, to: &buf)
        // Associative part (sorted keys for deterministic output)
        for key in associative.keys.sorted() {
            if let val = associative[key] {
                encodeAMF3String(key, into: &buf)
                try encodeValue(val, into: &buf)
            }
        }
        appendU29(0x01, to: &buf)  // empty string terminator
        // Dense part
        for element in dense {
            try encodeValue(element, into: &buf)
        }
    }

    // MARK: - Object

    private mutating func encodeObject(
        _ obj: AMF3Object, value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        guard !obj.traits.isExternalizable else {
            throw AMF3EncodingError.externalizableNotSupported
        }
        buf.append(AMF3Value.Marker.object)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        try encodeTraits(obj.traits, into: &buf)
        // Sealed property values (in declaration order)
        for propName in obj.traits.properties {
            let propVal = obj.sealedProperties[propName] ?? .undefined
            try encodeValue(propVal, into: &buf)
        }
        // Dynamic properties
        if obj.traits.isDynamic {
            for key in obj.dynamicProperties.keys.sorted() {
                if let val = obj.dynamicProperties[key] {
                    encodeAMF3String(key, into: &buf)
                    try encodeValue(val, into: &buf)
                }
            }
            appendU29(0x01, to: &buf)  // empty string terminator
        }
    }

    private mutating func encodeTraits(_ traits: AMF3Traits, into buf: inout [UInt8]) throws {
        if let refIndex = refs.traitsReference(for: traits) {
            appendU29((UInt32(refIndex) << 2) | 0x01, to: &buf)  // traits reference
            return
        }
        refs.addTraits(traits)
        var flags: UInt32 = 0x03  // inline traits
        if traits.isDynamic { flags |= 0x08 }
        if traits.isExternalizable { flags |= 0x04 }
        flags |= UInt32(traits.properties.count) << 4
        appendU29(flags, to: &buf)
        encodeAMF3String(traits.className, into: &buf)
        for propName in traits.properties {
            encodeAMF3String(propName, into: &buf)
        }
    }

    // MARK: - ByteArray

    private mutating func encodeByteArray(
        _ bytes: [UInt8], value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        buf.append(AMF3Value.Marker.byteArray)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        appendU29((UInt32(bytes.count) << 1) | 1, to: &buf)
        buf.append(contentsOf: bytes)
    }

}

// MARK: - Vectors, Dictionary & Byte Helpers

extension AMF3Encoder {

    mutating func encodeVectorInt(
        _ values: [Int32], fixed: Bool, value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        buf.append(AMF3Value.Marker.vectorInt)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        appendU29((UInt32(values.count) << 1) | 1, to: &buf)
        buf.append(fixed ? 0x01 : 0x00)
        for v in values { appendInt32BE(v, to: &buf) }
    }

    mutating func encodeVectorUInt(
        _ values: [UInt32], fixed: Bool, value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        buf.append(AMF3Value.Marker.vectorUInt)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        appendU29((UInt32(values.count) << 1) | 1, to: &buf)
        buf.append(fixed ? 0x01 : 0x00)
        for v in values { appendUInt32BE(v, to: &buf) }
    }

    mutating func encodeVectorDouble(
        _ values: [Double], fixed: Bool, value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        buf.append(AMF3Value.Marker.vectorDouble)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        appendU29((UInt32(values.count) << 1) | 1, to: &buf)
        buf.append(fixed ? 0x01 : 0x00)
        for v in values { appendDoubleBE(v, to: &buf) }
    }

    mutating func encodeVectorObject(
        _ values: [AMF3Value], typeName: String, fixed: Bool,
        value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        buf.append(AMF3Value.Marker.vectorObject)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        appendU29((UInt32(values.count) << 1) | 1, to: &buf)
        buf.append(fixed ? 0x01 : 0x00)
        encodeAMF3String(typeName, into: &buf)
        for element in values { try encodeValue(element, into: &buf) }
    }

    mutating func encodeDictionary(
        _ pairs: [(key: AMF3Value, value: AMF3Value)], weakKeys: Bool,
        value: AMF3Value, into buf: inout [UInt8]
    ) throws {
        buf.append(AMF3Value.Marker.dictionary)
        if let refIndex = refs.objectReference(for: value) {
            appendU29(UInt32(refIndex) << 1, to: &buf)
            return
        }
        refs.addObject(value)
        appendU29((UInt32(pairs.count) << 1) | 1, to: &buf)
        buf.append(weakKeys ? 0x01 : 0x00)
        for pair in pairs {
            try encodeValue(pair.key, into: &buf)
            try encodeValue(pair.value, into: &buf)
        }
    }

    // MARK: - U29 Encoding

    func appendU29(_ value: UInt32, to buf: inout [UInt8]) {
        if value < 0x80 {
            buf.append(UInt8(value))
        } else if value < 0x4000 {
            buf.append(UInt8(((value >> 7) & 0x7F) | 0x80))
            buf.append(UInt8(value & 0x7F))
        } else if value < 0x20_0000 {
            buf.append(UInt8(((value >> 14) & 0x7F) | 0x80))
            buf.append(UInt8(((value >> 7) & 0x7F) | 0x80))
            buf.append(UInt8(value & 0x7F))
        } else {
            buf.append(UInt8(((value >> 22) & 0x7F) | 0x80))
            buf.append(UInt8(((value >> 15) & 0x7F) | 0x80))
            buf.append(UInt8(((value >> 8) & 0x7F) | 0x80))
            buf.append(UInt8(value & 0xFF))
        }
    }

    // MARK: - Byte Helpers

    func appendDoubleBE(_ value: Double, to buf: inout [UInt8]) {
        let bits = value.bitPattern
        buf.append(UInt8((bits >> 56) & 0xFF))
        buf.append(UInt8((bits >> 48) & 0xFF))
        buf.append(UInt8((bits >> 40) & 0xFF))
        buf.append(UInt8((bits >> 32) & 0xFF))
        buf.append(UInt8((bits >> 24) & 0xFF))
        buf.append(UInt8((bits >> 16) & 0xFF))
        buf.append(UInt8((bits >> 8) & 0xFF))
        buf.append(UInt8(bits & 0xFF))
    }

    func appendInt32BE(_ value: Int32, to buf: inout [UInt8]) {
        appendUInt32BE(UInt32(bitPattern: value), to: &buf)
    }

    func appendUInt32BE(_ value: UInt32, to buf: inout [UInt8]) {
        buf.append(UInt8((value >> 24) & 0xFF))
        buf.append(UInt8((value >> 16) & 0xFF))
        buf.append(UInt8((value >> 8) & 0xFF))
        buf.append(UInt8(value & 0xFF))
    }
}
