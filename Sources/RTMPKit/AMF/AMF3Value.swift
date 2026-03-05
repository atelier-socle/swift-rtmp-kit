// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A Swift representation of an AMF3 value, covering all 18 types
/// defined in the Adobe AMF3 specification.
public indirect enum AMF3Value: Sendable {
    /// 0x00 — undefined.
    case undefined
    /// 0x01 — null.
    case null
    /// 0x02 — boolean false.
    case `false`
    /// 0x03 — boolean true.
    case `true`
    /// 0x04 — 29-bit signed integer (U29 variable-length encoding).
    case integer(Int32)
    /// 0x05 — IEEE 754 double-precision float.
    case double(Double)
    /// 0x06 — UTF-8 string (with string reference table).
    case string(String)
    /// 0x07 — XML document (legacy).
    case xmlDocument(String)
    /// 0x08 — Date (milliseconds since Unix epoch).
    case date(Double)
    /// 0x09 — Array (dense part + associative part).
    case array(dense: [AMF3Value], associative: [String: AMF3Value])
    /// 0x0A — Object (dynamic/sealed, with traits).
    case object(AMF3Object)
    /// 0x0B — XML (E4X).
    case xml(String)
    /// 0x0C — ByteArray (raw bytes).
    case byteArray([UInt8])
    /// 0x0D — Vector<int>.
    case vectorInt([Int32], fixed: Bool)
    /// 0x0E — Vector<uint>.
    case vectorUInt([UInt32], fixed: Bool)
    /// 0x0F — Vector<double>.
    case vectorDouble([Double], fixed: Bool)
    /// 0x10 — Vector<Object>.
    case vectorObject([AMF3Value], typeName: String, fixed: Bool)
    /// 0x11 — Dictionary (with weak-key flag).
    case dictionary([(key: AMF3Value, value: AMF3Value)], weakKeys: Bool)
}

// MARK: - Type Markers

extension AMF3Value {
    /// AMF3 type marker byte constants.
    public enum Marker {
        /// Undefined type marker (`0x00`).
        public static let undefined: UInt8 = 0x00
        /// Null type marker (`0x01`).
        public static let null: UInt8 = 0x01
        /// False type marker (`0x02`).
        public static let `false`: UInt8 = 0x02
        /// True type marker (`0x03`).
        public static let `true`: UInt8 = 0x03
        /// Integer type marker (`0x04`).
        public static let integer: UInt8 = 0x04
        /// Double type marker (`0x05`).
        public static let double: UInt8 = 0x05
        /// String type marker (`0x06`).
        public static let string: UInt8 = 0x06
        /// XML document type marker (`0x07`).
        public static let xmlDocument: UInt8 = 0x07
        /// Date type marker (`0x08`).
        public static let date: UInt8 = 0x08
        /// Array type marker (`0x09`).
        public static let array: UInt8 = 0x09
        /// Object type marker (`0x0A`).
        public static let object: UInt8 = 0x0A
        /// XML (E4X) type marker (`0x0B`).
        public static let xml: UInt8 = 0x0B
        /// ByteArray type marker (`0x0C`).
        public static let byteArray: UInt8 = 0x0C
        /// Vector<int> type marker (`0x0D`).
        public static let vectorInt: UInt8 = 0x0D
        /// Vector<uint> type marker (`0x0E`).
        public static let vectorUInt: UInt8 = 0x0E
        /// Vector<double> type marker (`0x0F`).
        public static let vectorDouble: UInt8 = 0x0F
        /// Vector<Object> type marker (`0x10`).
        public static let vectorObject: UInt8 = 0x10
        /// Dictionary type marker (`0x11`).
        public static let dictionary: UInt8 = 0x11
    }
}

// MARK: - Equatable

extension AMF3Value: Equatable {
    public static func == (lhs: AMF3Value, rhs: AMF3Value) -> Bool {
        switch (lhs, rhs) {
        case (.undefined, .undefined), (.null, .null),
            (.false, .false), (.true, .true):
            return true
        case let (.integer(a), .integer(b)):
            return a == b
        case let (.double(a), .double(b)):
            return a.bitPattern == b.bitPattern
        case let (.string(a), .string(b)):
            return a == b
        case let (.xmlDocument(a), .xmlDocument(b)):
            return a == b
        case let (.date(a), .date(b)):
            return a.bitPattern == b.bitPattern
        case let (.xml(a), .xml(b)):
            return a == b
        case let (.byteArray(a), .byteArray(b)):
            return a == b
        default:
            return isEqualComplex(lhs, rhs)
        }
    }

    private static func isEqualComplex(_ lhs: AMF3Value, _ rhs: AMF3Value) -> Bool {
        switch (lhs, rhs) {
        case let (.array(dA, aA), .array(dB, aB)):
            return dA == dB && aA == aB
        case let (.object(a), .object(b)):
            return a == b
        case let (.vectorInt(vA, fA), .vectorInt(vB, fB)):
            return vA == vB && fA == fB
        case let (.vectorUInt(vA, fA), .vectorUInt(vB, fB)):
            return vA == vB && fA == fB
        case let (.vectorDouble(vA, fA), .vectorDouble(vB, fB)):
            return vectorDoubleEqual(vA, vB) && fA == fB
        case let (.vectorObject(vA, tA, fA), .vectorObject(vB, tB, fB)):
            return vA == vB && tA == tB && fA == fB
        case let (.dictionary(pA, wA), .dictionary(pB, wB)):
            return wA == wB && dictionaryPairsEqual(pA, pB)
        default:
            return false
        }
    }

    private static func vectorDoubleEqual(_ a: [Double], _ b: [Double]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) where x.bitPattern != y.bitPattern {
            return false
        }
        return true
    }

    private static func dictionaryPairsEqual(
        _ a: [(key: AMF3Value, value: AMF3Value)],
        _ b: [(key: AMF3Value, value: AMF3Value)]
    ) -> Bool {
        guard a.count == b.count else { return false }
        for (pairA, pairB) in zip(a, b) {
            if pairA.key != pairB.key || pairA.value != pairB.value { return false }
        }
        return true
    }
}

// MARK: - Convenience Accessors

extension AMF3Value {
    /// Returns `true` if this value is `.null` or `.undefined`.
    public var isNull: Bool {
        switch self {
        case .null, .undefined: return true
        default: return false
        }
    }

    /// Returns the string if this is `.string`, `.xmlDocument`, or `.xml`.
    public var stringValue: String? {
        switch self {
        case let .string(v): return v
        case let .xmlDocument(v): return v
        case let .xml(v): return v
        default: return nil
        }
    }

    /// Returns the double if this is `.double`.
    public var doubleValue: Double? {
        if case let .double(v) = self { return v }
        return nil
    }

    /// Returns the integer if this is `.integer`.
    public var intValue: Int32? {
        if case let .integer(v) = self { return v }
        return nil
    }

    /// Returns the boolean value if this is `.true` or `.false`.
    public var boolValue: Bool? {
        switch self {
        case .true: return true
        case .false: return false
        default: return nil
        }
    }

    /// Returns the byte array if this is `.byteArray`.
    public var byteArrayValue: [UInt8]? {
        if case let .byteArray(v) = self { return v }
        return nil
    }
}
