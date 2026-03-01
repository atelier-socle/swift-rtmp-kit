// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Builds FLV script data tag bodies (AMF0-encoded metadata).
///
/// Script data tags carry AMF0-encoded metadata in RTMP data messages
/// (type 18). This enum provides encoding/decoding at the FLV tag body
/// level, delegating to the existing AMF0 encoder/decoder.
public enum FLVScriptTag: Sendable {

    /// Build a script data tag body from AMF0 values.
    ///
    /// This is the raw tag body for RTMP data messages (type 18).
    ///
    /// - Parameter values: The AMF0 values to encode.
    /// - Returns: The encoded tag body bytes.
    public static func encode(values: [AMF0Value]) -> [UInt8] {
        var encoder = AMF0Encoder()
        return encoder.encode(values)
    }

    /// Decode a script data tag body to AMF0 values.
    ///
    /// - Parameter bytes: The tag body bytes.
    /// - Returns: The decoded AMF0 values.
    /// - Throws: `AMF0Error` if the data is malformed.
    public static func decode(from bytes: [UInt8]) throws -> [AMF0Value] {
        var decoder = AMF0Decoder()
        return try decoder.decodeAll(from: bytes)
    }
}
