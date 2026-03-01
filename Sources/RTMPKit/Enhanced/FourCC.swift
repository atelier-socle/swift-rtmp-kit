// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// FourCC (Four Character Code) codec identifier.
///
/// FourCC values are 4 ASCII bytes packed into a UInt32.
/// Used in Enhanced RTMP v2 for modern codec signaling.
public struct FourCC: RawRepresentable, Sendable, Equatable, Hashable {

    /// The raw UInt32 value (4 ASCII bytes packed big-endian).
    public let rawValue: UInt32

    /// Creates a FourCC from a raw UInt32 value.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Creates a FourCC from a 4-character ASCII string.
    ///
    /// - Parameter stringValue: A 4-character ASCII string (e.g., "hvc1").
    public init(stringValue: String) {
        let bytes = Array(stringValue.utf8)
        var value: UInt32 = 0
        for i in 0..<min(4, bytes.count) {
            value |= UInt32(bytes[i]) << UInt32((3 - i) * 8)
        }
        self.rawValue = value
    }

    /// The 4-character string representation.
    public var stringValue: String {
        let bytes = [
            UInt8((rawValue >> 24) & 0xFF),
            UInt8((rawValue >> 16) & 0xFF),
            UInt8((rawValue >> 8) & 0xFF),
            UInt8(rawValue & 0xFF)
        ]
        return String(bytes.map { Character(UnicodeScalar($0)) })
    }

    /// Encode FourCC to 4 bytes (the 4 ASCII bytes in order).
    ///
    /// - Returns: A 4-byte array.
    public func encode() -> [UInt8] {
        [
            UInt8((rawValue >> 24) & 0xFF),
            UInt8((rawValue >> 16) & 0xFF),
            UInt8((rawValue >> 8) & 0xFF),
            UInt8(rawValue & 0xFF)
        ]
    }

    /// Decode FourCC from 4 bytes.
    ///
    /// - Parameter bytes: At least 4 bytes.
    /// - Returns: The decoded FourCC.
    /// - Throws: `FLVError.truncatedData` if fewer than 4 bytes.
    public static func decode(from bytes: [UInt8]) throws -> FourCC {
        guard bytes.count >= 4 else {
            throw FLVError.truncatedData(expected: 4, actual: bytes.count)
        }
        let value =
            UInt32(bytes[0]) << 24
            | UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8
            | UInt32(bytes[3])
        return FourCC(rawValue: value)
    }

    // MARK: - Video Codecs

    /// H.265 / HEVC.
    public static let hevc = FourCC(stringValue: "hvc1")
    /// AV1.
    public static let av1 = FourCC(stringValue: "av01")
    /// VP9.
    public static let vp9 = FourCC(stringValue: "vp09")

    // MARK: - Audio Codecs

    /// Opus.
    public static let opus = FourCC(stringValue: "Opus")
    /// FLAC.
    public static let flac = FourCC(stringValue: "fLaC")
    /// Dolby Digital (AC-3).
    public static let ac3 = FourCC(stringValue: "ac-3")
    /// Dolby Digital Plus (E-AC-3).
    public static let eac3 = FourCC(stringValue: "ec-3")
    /// AAC (enhanced signaling).
    public static let mp4a = FourCC(stringValue: "mp4a")

    // MARK: - Classification

    /// Whether this FourCC identifies a video codec.
    public var isVideoCodec: Bool {
        Self.allVideo.contains(self)
    }

    /// Whether this FourCC identifies an audio codec.
    public var isAudioCodec: Bool {
        Self.allAudio.contains(self)
    }

    /// All known video FourCC values.
    public static var allVideo: [FourCC] {
        [.hevc, .av1, .vp9]
    }

    /// All known audio FourCC values.
    public static var allAudio: [FourCC] {
        [.opus, .flac, .ac3, .eac3, .mp4a]
    }
}

// MARK: - CustomStringConvertible

extension FourCC: CustomStringConvertible {
    /// A description including the 4-character string.
    public var description: String {
        "FourCC(\(stringValue))"
    }
}
