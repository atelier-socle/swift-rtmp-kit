// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// FLV tag types.
public enum FLVTagType: UInt8, Sendable {
    /// Audio tag (type 8).
    case audio = 8
    /// Video tag (type 9).
    case video = 9
    /// Script data tag (type 18).
    case scriptData = 18
}

/// Errors that occur during FLV tag processing.
public enum FLVError: Error, Sendable, Equatable {
    /// Data is too short for the expected format.
    case truncatedData(expected: Int, actual: Int)
    /// Invalid FLV file signature.
    case invalidSignature
    /// Invalid or unsupported format.
    case invalidFormat(String)
}
