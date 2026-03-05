// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Video codec detected in an FLV file.
public enum FLVVideoCodec: Sendable, Equatable {
    /// H.264 / AVC (legacy RTMP).
    case h264
    /// H.265 / HEVC (requires Enhanced RTMP).
    case hevc
    /// AV1 (requires Enhanced RTMP).
    case av1
    /// VP9 (requires Enhanced RTMP).
    case vp9
    /// Unknown or undetected video codec.
    case unknown

    /// Whether this codec requires Enhanced RTMP v2 signaling.
    public var requiresEnhancedRTMP: Bool {
        self != .h264 && self != .unknown
    }

    /// Human-readable codec name for display.
    public var displayName: String {
        switch self {
        case .h264: "H.264"
        case .hevc: "HEVC (H.265)"
        case .av1: "AV1"
        case .vp9: "VP9"
        case .unknown: "Unknown"
        }
    }
}

/// Audio codec detected in an FLV file.
public enum FLVAudioCodec: Sendable, Equatable {
    /// AAC (legacy RTMP).
    case aac
    /// Opus (requires Enhanced RTMP).
    case opus
    /// Unknown or undetected audio codec.
    case unknown

    /// Human-readable codec name for display.
    public var displayName: String {
        switch self {
        case .aac: "AAC"
        case .opus: "Opus"
        case .unknown: "Unknown"
        }
    }
}

/// Codec information detected from an FLV file.
public struct FLVCodecInfo: Sendable, Equatable {
    /// The detected video codec.
    public let videoCodec: FLVVideoCodec
    /// The detected audio codec.
    public let audioCodec: FLVAudioCodec

    /// Creates codec info with the given video and audio codecs.
    ///
    /// - Parameters:
    ///   - videoCodec: The detected video codec.
    ///   - audioCodec: The detected audio codec.
    public init(videoCodec: FLVVideoCodec, audioCodec: FLVAudioCodec) {
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
    }
}

/// Probes an FLV file's raw bytes to detect video and audio codecs.
///
/// Scans FLV tag headers to identify the codecs used in the file.
/// Supports both legacy codec IDs and Enhanced RTMP v2 FourCC signaling.
/// Stops as soon as both video and audio codecs are identified.
public enum FLVCodecProbe {

    /// Probe FLV data to detect codecs.
    ///
    /// - Parameters:
    ///   - data: The raw FLV file bytes.
    ///   - dataOffset: The byte offset where FLV tags begin (after header).
    /// - Returns: Detected codec information.
    public static func probe(data: [UInt8], dataOffset: Int) -> FLVCodecInfo {
        var offset = dataOffset
        var videoCodec: FLVVideoCodec?
        var audioCodec: FLVAudioCodec?

        while offset + 11 <= data.count {
            let tagType = data[offset]
            let dataSize =
                Int(data[offset + 1]) << 16
                | Int(data[offset + 2]) << 8
                | Int(data[offset + 3])

            let headerSize = 11
            let payloadStart = offset + headerSize
            let payloadEnd = payloadStart + dataSize

            guard payloadEnd <= data.count, dataSize > 0 else { break }

            if tagType == 9, videoCodec == nil {
                videoCodec = detectVideoCodec(
                    data: data, payloadStart: payloadStart, payloadSize: dataSize
                )
            } else if tagType == 8, audioCodec == nil {
                audioCodec = detectAudioCodec(
                    data: data, payloadStart: payloadStart, payloadSize: dataSize
                )
            }

            if videoCodec != nil, audioCodec != nil {
                break
            }

            offset = payloadEnd + 4
        }

        return FLVCodecInfo(
            videoCodec: videoCodec ?? .unknown,
            audioCodec: audioCodec ?? .unknown
        )
    }

    // MARK: - Private

    private static func detectVideoCodec(
        data: [UInt8], payloadStart: Int, payloadSize: Int
    ) -> FLVVideoCodec {
        let byte0 = data[payloadStart]
        if ExVideoHeader.isExHeader(byte0) {
            guard payloadSize >= 5 else { return .unknown }
            let fourCCRaw =
                UInt32(data[payloadStart + 1]) << 24
                | UInt32(data[payloadStart + 2]) << 16
                | UInt32(data[payloadStart + 3]) << 8
                | UInt32(data[payloadStart + 4])
            let fourCC = FourCC(rawValue: fourCCRaw)
            return mapVideoFourCC(fourCC)
        }
        let codecID = byte0 & 0x0F
        if codecID == 7 {
            return .h264
        }
        return .unknown
    }

    private static func detectAudioCodec(
        data: [UInt8], payloadStart: Int, payloadSize: Int
    ) -> FLVAudioCodec {
        let byte0 = data[payloadStart]
        // Legacy AAC: SoundFormat=10 (0xA in upper nibble), byte0 in 0xA0..0xAF.
        // Must check legacy first because 0xAF has bit 7 set (same as enhanced).
        let soundFormat = (byte0 >> 4) & 0x0F
        if soundFormat == 10 {
            return .aac
        }
        // Enhanced audio: bit 7 set with non-legacy SoundFormat.
        if ExAudioHeader.isExHeader(byte0) {
            guard payloadSize >= 5 else { return .unknown }
            let fourCCRaw =
                UInt32(data[payloadStart + 1]) << 24
                | UInt32(data[payloadStart + 2]) << 16
                | UInt32(data[payloadStart + 3]) << 8
                | UInt32(data[payloadStart + 4])
            let fourCC = FourCC(rawValue: fourCCRaw)
            return mapAudioFourCC(fourCC)
        }
        return .unknown
    }

    private static func mapVideoFourCC(_ fourCC: FourCC) -> FLVVideoCodec {
        switch fourCC {
        case .hevc: .hevc
        case .av1: .av1
        case .vp9: .vp9
        default: .unknown
        }
    }

    private static func mapAudioFourCC(_ fourCC: FourCC) -> FLVAudioCodec {
        switch fourCC {
        case .opus: .opus
        default: .unknown
        }
    }
}
