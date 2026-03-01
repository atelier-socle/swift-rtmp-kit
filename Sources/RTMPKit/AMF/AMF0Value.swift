// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// AMF0 value types as defined by the Adobe AMF0 specification (December 2007).
///
/// AMF0 is the binary serialization format used for all RTMP command messages,
/// data messages, and metadata. Every RTMP command (`connect`, `createStream`,
/// `publish`, etc.) is encoded as a sequence of AMF0 values.
///
/// Objects and ECMAArrays use ordered key-value pairs `[(String, AMF0Value)]`
/// instead of dictionaries to preserve insertion order, which is critical
/// for RTMP protocol correctness.
public enum AMF0Value: Sendable {
    /// IEEE 754 double-precision floating-point number (marker `0x00`).
    case number(Double)

    /// Boolean value (marker `0x01`).
    case boolean(Bool)

    /// UTF-8 string with length up to 65535 bytes (marker `0x02`).
    case string(String)

    /// Object with ordered key-value pairs (marker `0x03`).
    case object([(String, AMF0Value)])

    /// Null value (marker `0x05`).
    case null

    /// Undefined value (marker `0x06`).
    case undefined

    /// Reference to a previously serialized object (marker `0x07`).
    case reference(UInt16)

    /// ECMA array (associative) with ordered key-value pairs (marker `0x08`).
    case ecmaArray([(String, AMF0Value)])

    /// Strict array of values without keys (marker `0x0A`).
    case strictArray([AMF0Value])

    /// Date as milliseconds since Unix epoch with timezone offset (marker `0x0B`).
    case date(Double, timeZoneOffset: Int16)

    /// Long UTF-8 string with length up to `UInt32.max` bytes (marker `0x0C`).
    case longString(String)

    /// Unsupported value type (marker `0x0D`).
    case unsupported

    /// XML document as a long string (marker `0x0F`).
    case xmlDocument(String)

    /// Typed object with class name and ordered properties (marker `0x10`).
    case typedObject(className: String, properties: [(String, AMF0Value)])
}

// MARK: - Type Markers

extension AMF0Value {
    /// AMF0 type marker byte constants.
    public enum Marker {
        /// Number type marker (`0x00`).
        public static let number: UInt8 = 0x00
        /// Boolean type marker (`0x01`).
        public static let boolean: UInt8 = 0x01
        /// String type marker (`0x02`).
        public static let string: UInt8 = 0x02
        /// Object type marker (`0x03`).
        public static let object: UInt8 = 0x03
        /// MovieClip reserved marker (`0x04`).
        public static let movieClipReserved: UInt8 = 0x04
        /// Null type marker (`0x05`).
        public static let null: UInt8 = 0x05
        /// Undefined type marker (`0x06`).
        public static let undefined: UInt8 = 0x06
        /// Reference type marker (`0x07`).
        public static let reference: UInt8 = 0x07
        /// ECMA array type marker (`0x08`).
        public static let ecmaArray: UInt8 = 0x08
        /// Object end marker (`0x09`).
        public static let objectEnd: UInt8 = 0x09
        /// Strict array type marker (`0x0A`).
        public static let strictArray: UInt8 = 0x0A
        /// Date type marker (`0x0B`).
        public static let date: UInt8 = 0x0B
        /// Long string type marker (`0x0C`).
        public static let longString: UInt8 = 0x0C
        /// Unsupported type marker (`0x0D`).
        public static let unsupported: UInt8 = 0x0D
        /// RecordSet reserved marker (`0x0E`).
        public static let recordSetReserved: UInt8 = 0x0E
        /// XML document type marker (`0x0F`).
        public static let xmlDocument: UInt8 = 0x0F
        /// Typed object type marker (`0x10`).
        public static let typedObject: UInt8 = 0x10
    }
}

// MARK: - Equatable

extension AMF0Value: Equatable {
    public static func == (lhs: AMF0Value, rhs: AMF0Value) -> Bool {
        switch (lhs, rhs) {
        case let (.number(a), .number(b)):
            return a.bitPattern == b.bitPattern
        case let (.boolean(a), .boolean(b)):
            return a == b
        case let (.string(a), .string(b)),
            let (.longString(a), .longString(b)),
            let (.xmlDocument(a), .xmlDocument(b)):
            return a == b
        case let (.object(a), .object(b)),
            let (.ecmaArray(a), .ecmaArray(b)):
            return orderedPairsEqual(a, b)
        case (.null, .null), (.undefined, .undefined), (.unsupported, .unsupported):
            return true
        case let (.reference(a), .reference(b)):
            return a == b
        case let (.strictArray(a), .strictArray(b)):
            return a == b
        case let (.date(msA, tzA), .date(msB, tzB)):
            return msA.bitPattern == msB.bitPattern && tzA == tzB
        default:
            return isEqualCompound(lhs, rhs)
        }
    }

    private static func isEqualCompound(_ lhs: AMF0Value, _ rhs: AMF0Value) -> Bool {
        switch (lhs, rhs) {
        case let (.typedObject(classA, propsA), .typedObject(classB, propsB)):
            return classA == classB && orderedPairsEqual(propsA, propsB)
        default:
            return false
        }
    }

    private static func orderedPairsEqual(
        _ lhs: [(String, AMF0Value)],
        _ rhs: [(String, AMF0Value)]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (a, b) in zip(lhs, rhs) {
            if a.0 != b.0 || a.1 != b.1 { return false }
        }
        return true
    }
}

// MARK: - Convenience Accessors

extension AMF0Value {
    /// Returns the double value if this is a `.number`, otherwise `nil`.
    public var numberValue: Double? {
        if case let .number(v) = self { return v }
        return nil
    }

    /// Returns the boolean value if this is a `.boolean`, otherwise `nil`.
    public var booleanValue: Bool? {
        if case let .boolean(v) = self { return v }
        return nil
    }

    /// Returns the string value if this is a `.string` or `.longString`, otherwise `nil`.
    public var stringValue: String? {
        switch self {
        case let .string(v): return v
        case let .longString(v): return v
        default: return nil
        }
    }

    /// Returns the ordered key-value pairs if this is an `.object`, otherwise `nil`.
    public var objectProperties: [(String, AMF0Value)]? {
        if case let .object(pairs) = self { return pairs }
        return nil
    }

    /// Returns the ordered key-value pairs if this is an `.ecmaArray`, otherwise `nil`.
    public var ecmaArrayEntries: [(String, AMF0Value)]? {
        if case let .ecmaArray(pairs) = self { return pairs }
        return nil
    }

    /// Returns the array elements if this is a `.strictArray`, otherwise `nil`.
    public var arrayElements: [AMF0Value]? {
        if case let .strictArray(values) = self { return values }
        return nil
    }

    /// Returns `true` if this value is `.null`.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// Returns `true` if this value is `.undefined`.
    public var isUndefined: Bool {
        if case .undefined = self { return true }
        return false
    }
}

// MARK: - CustomStringConvertible

extension AMF0Value: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .number(v): return "AMF0.number(\(v))"
        case let .boolean(v): return "AMF0.boolean(\(v))"
        case let .string(v): return "AMF0.string(\"\(v)\")"
        case let .object(pairs): return "AMF0.object(\(describePairs(pairs)))"
        case .null: return "AMF0.null"
        case .undefined: return "AMF0.undefined"
        case let .reference(idx): return "AMF0.reference(\(idx))"
        case let .ecmaArray(pairs): return "AMF0.ecmaArray(\(describePairs(pairs)))"
        case let .strictArray(values): return "AMF0.strictArray(\(values))"
        case let .date(ms, tz): return "AMF0.date(\(ms), tz: \(tz))"
        case let .longString(v): return "AMF0.longString(\"\(v.prefix(50))...\")"
        case .unsupported: return "AMF0.unsupported"
        case let .xmlDocument(v): return "AMF0.xmlDocument(\"\(v.prefix(50))...\")"
        case let .typedObject(name, pairs):
            return "AMF0.typedObject(\"\(name)\", \(describePairs(pairs)))"
        }
    }

    private func describePairs(_ pairs: [(String, AMF0Value)]) -> String {
        let items = pairs.map { "\"\($0.0)\": \($0.1)" }
        return "[\(items.joined(separator: ", "))]"
    }
}
