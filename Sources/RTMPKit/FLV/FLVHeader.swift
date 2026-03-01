// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// FLV file header (9 bytes) — for potential recording functionality.
///
/// Not used in RTMP streaming directly, but needed if recording
/// the stream to an FLV file.
///
/// Format:
/// - Bytes 0-2: "FLV" signature (0x46, 0x4C, 0x56)
/// - Byte 3: Version = 1
/// - Byte 4: Flags (bit 0 = has video, bit 2 = has audio)
/// - Bytes 5-8: Data offset = 9 (uint32 BE)
public struct FLVHeader: Sendable, Equatable {

    /// Whether audio tags are present.
    public var hasAudio: Bool

    /// Whether video tags are present.
    public var hasVideo: Bool

    /// Creates an FLV header.
    ///
    /// - Parameters:
    ///   - hasAudio: Whether audio tags are present.
    ///   - hasVideo: Whether video tags are present.
    public init(hasAudio: Bool = false, hasVideo: Bool = false) {
        self.hasAudio = hasAudio
        self.hasVideo = hasVideo
    }

    /// Serialize to 9-byte FLV file header.
    ///
    /// - Returns: A 9-byte FLV file header.
    public func encode() -> [UInt8] {
        var flags: UInt8 = 0
        if hasAudio { flags |= 0x04 }
        if hasVideo { flags |= 0x01 }
        return [
            0x46, 0x4C, 0x56,  // "FLV"
            0x01,  // version
            flags,
            0x00, 0x00, 0x00, 0x09  // data offset = 9
        ]
    }

    /// Parse from bytes.
    ///
    /// - Parameter bytes: At least 9 bytes.
    /// - Returns: The parsed FLV header.
    /// - Throws: `FLVError` on invalid signature or insufficient data.
    public static func decode(from bytes: [UInt8]) throws -> FLVHeader {
        guard bytes.count >= 9 else {
            throw FLVError.truncatedData(expected: 9, actual: bytes.count)
        }
        guard bytes[0] == 0x46, bytes[1] == 0x4C, bytes[2] == 0x56 else {
            throw FLVError.invalidSignature
        }
        let flags = bytes[4]
        return FLVHeader(
            hasAudio: (flags & 0x04) != 0,
            hasVideo: (flags & 0x01) != 0
        )
    }
}
