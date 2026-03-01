// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Encodes AMF0 values to binary data.
///
/// The encoder serializes ``AMF0Value`` instances into `[UInt8]` byte arrays
/// following the Adobe AMF0 specification. All multi-byte integers and IEEE 754
/// doubles are encoded in big-endian byte order.
///
/// The encoder maintains a reference table for objects, ECMA arrays, and typed
/// objects. While the table is tracked, the encoder always writes the full object
/// (callers can explicitly use `.reference(index)` when needed).
///
/// ## Usage
///
/// ```swift
/// var encoder = AMF0Encoder()
/// let bytes = encoder.encode(.string("hello"))
/// ```
public struct AMF0Encoder: Sendable {
    private var referenceTable: [Int] = []

    /// Creates a new AMF0 encoder.
    public init() {}

    /// Encodes a single AMF0 value to binary data.
    ///
    /// - Parameter value: The AMF0 value to encode.
    /// - Returns: The encoded bytes.
    public mutating func encode(_ value: AMF0Value) -> [UInt8] {
        var buffer: [UInt8] = []
        encodeValue(value, into: &buffer)
        return buffer
    }

    /// Encodes multiple AMF0 values sequentially.
    ///
    /// - Parameter values: The AMF0 values to encode.
    /// - Returns: The concatenated encoded bytes.
    public mutating func encode(_ values: [AMF0Value]) -> [UInt8] {
        var buffer: [UInt8] = []
        for value in values {
            encodeValue(value, into: &buffer)
        }
        return buffer
    }

    /// Resets the reference table for a new encoding context.
    public mutating func reset() {
        referenceTable.removeAll()
    }

    // MARK: - Private

    private mutating func encodeValue(_ value: AMF0Value, into buffer: inout [UInt8]) {
        switch value {
        case let .number(v):
            encodeNumber(v, into: &buffer)
        case let .boolean(v):
            encodeBoolean(v, into: &buffer)
        case let .string(v):
            encodeStringAuto(v, into: &buffer)
        case let .object(pairs):
            encodeObject(pairs, into: &buffer)
        case .null, .undefined, .unsupported:
            encodeMarkerOnly(value, into: &buffer)
        case let .reference(index):
            encodeReference(index, into: &buffer)
        default:
            encodeContainerValue(value, into: &buffer)
        }
    }

    private mutating func encodeContainerValue(_ value: AMF0Value, into buffer: inout [UInt8]) {
        switch value {
        case let .ecmaArray(pairs):
            encodeECMAArray(pairs, into: &buffer)
        case let .strictArray(values):
            encodeStrictArray(values, into: &buffer)
        case let .date(ms, timeZoneOffset: tz):
            encodeDate(ms, timeZoneOffset: tz, into: &buffer)
        case let .longString(v):
            encodeLongString(v, into: &buffer)
        case let .xmlDocument(v):
            encodeXMLDocument(v, into: &buffer)
        case let .typedObject(className, properties):
            encodeTypedObject(className: className, properties: properties, into: &buffer)
        default:
            break
        }
    }

    private func encodeMarkerOnly(_ value: AMF0Value, into buffer: inout [UInt8]) {
        switch value {
        case .null: buffer.append(AMF0Value.Marker.null)
        case .undefined: buffer.append(AMF0Value.Marker.undefined)
        case .unsupported: buffer.append(AMF0Value.Marker.unsupported)
        default: break
        }
    }

    private func encodeNumber(_ value: Double, into buffer: inout [UInt8]) {
        buffer.append(AMF0Value.Marker.number)
        appendDoubleBE(value, to: &buffer)
    }

    private func encodeBoolean(_ value: Bool, into buffer: inout [UInt8]) {
        buffer.append(AMF0Value.Marker.boolean)
        buffer.append(value ? 0x01 : 0x00)
    }

    /// Auto-selects String (0x02) or LongString (0x0C) based on UTF-8 byte length.
    private mutating func encodeStringAuto(_ value: String, into buffer: inout [UInt8]) {
        let utf8 = Array(value.utf8)
        if utf8.count > Int(UInt16.max) {
            buffer.append(AMF0Value.Marker.longString)
            appendUInt32BE(UInt32(utf8.count), to: &buffer)
            buffer.append(contentsOf: utf8)
        } else {
            buffer.append(AMF0Value.Marker.string)
            appendUInt16BE(UInt16(utf8.count), to: &buffer)
            buffer.append(contentsOf: utf8)
        }
    }

    private mutating func encodeObject(
        _ pairs: [(String, AMF0Value)],
        into buffer: inout [UInt8]
    ) {
        referenceTable.append(referenceTable.count)
        buffer.append(AMF0Value.Marker.object)
        encodePairs(pairs, into: &buffer)
        appendObjectEnd(to: &buffer)
    }

    private func encodeReference(_ index: UInt16, into buffer: inout [UInt8]) {
        buffer.append(AMF0Value.Marker.reference)
        appendUInt16BE(index, to: &buffer)
    }

    private mutating func encodeECMAArray(
        _ pairs: [(String, AMF0Value)],
        into buffer: inout [UInt8]
    ) {
        referenceTable.append(referenceTable.count)
        buffer.append(AMF0Value.Marker.ecmaArray)
        appendUInt32BE(UInt32(pairs.count), to: &buffer)
        encodePairs(pairs, into: &buffer)
        appendObjectEnd(to: &buffer)
    }

    private mutating func encodeStrictArray(
        _ values: [AMF0Value],
        into buffer: inout [UInt8]
    ) {
        buffer.append(AMF0Value.Marker.strictArray)
        appendUInt32BE(UInt32(values.count), to: &buffer)
        for value in values {
            encodeValue(value, into: &buffer)
        }
    }

    private func encodeDate(
        _ ms: Double,
        timeZoneOffset tz: Int16,
        into buffer: inout [UInt8]
    ) {
        buffer.append(AMF0Value.Marker.date)
        appendDoubleBE(ms, to: &buffer)
        appendInt16BE(tz, to: &buffer)
    }

    private func encodeLongString(_ value: String, into buffer: inout [UInt8]) {
        let utf8 = Array(value.utf8)
        buffer.append(AMF0Value.Marker.longString)
        appendUInt32BE(UInt32(utf8.count), to: &buffer)
        buffer.append(contentsOf: utf8)
    }

    private func encodeXMLDocument(_ value: String, into buffer: inout [UInt8]) {
        let utf8 = Array(value.utf8)
        buffer.append(AMF0Value.Marker.xmlDocument)
        appendUInt32BE(UInt32(utf8.count), to: &buffer)
        buffer.append(contentsOf: utf8)
    }

    private mutating func encodeTypedObject(
        className: String,
        properties: [(String, AMF0Value)],
        into buffer: inout [UInt8]
    ) {
        referenceTable.append(referenceTable.count)
        buffer.append(AMF0Value.Marker.typedObject)
        let classUTF8 = Array(className.utf8)
        appendUInt16BE(UInt16(classUTF8.count), to: &buffer)
        buffer.append(contentsOf: classUTF8)
        encodePairs(properties, into: &buffer)
        appendObjectEnd(to: &buffer)
    }

    // MARK: - Helpers

    /// Encodes key-value pairs with bare string keys (no type marker).
    private mutating func encodePairs(
        _ pairs: [(String, AMF0Value)],
        into buffer: inout [UInt8]
    ) {
        for (key, value) in pairs {
            let keyUTF8 = Array(key.utf8)
            appendUInt16BE(UInt16(keyUTF8.count), to: &buffer)
            buffer.append(contentsOf: keyUTF8)
            encodeValue(value, into: &buffer)
        }
    }

    /// Appends the object end sequence: `0x00 0x00 0x09`.
    private func appendObjectEnd(to buffer: inout [UInt8]) {
        buffer.append(0x00)
        buffer.append(0x00)
        buffer.append(AMF0Value.Marker.objectEnd)
    }

    private func appendDoubleBE(_ value: Double, to buffer: inout [UInt8]) {
        let bits = value.bitPattern
        appendUInt64BE(bits, to: &buffer)
    }

    private func appendUInt64BE(_ value: UInt64, to buffer: inout [UInt8]) {
        buffer.append(UInt8((value >> 56) & 0xFF))
        buffer.append(UInt8((value >> 48) & 0xFF))
        buffer.append(UInt8((value >> 40) & 0xFF))
        buffer.append(UInt8((value >> 32) & 0xFF))
        buffer.append(UInt8((value >> 24) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8(value & 0xFF))
    }

    private func appendUInt32BE(_ value: UInt32, to buffer: inout [UInt8]) {
        buffer.append(UInt8((value >> 24) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8(value & 0xFF))
    }

    private func appendUInt16BE(_ value: UInt16, to buffer: inout [UInt8]) {
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8(value & 0xFF))
    }

    private func appendInt16BE(_ value: Int16, to buffer: inout [UInt8]) {
        let unsigned = UInt16(bitPattern: value)
        appendUInt16BE(unsigned, to: &buffer)
    }
}
