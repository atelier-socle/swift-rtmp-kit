// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Builds FLV audio tag bodies for RTMP audio messages.
///
/// Supports legacy AAC encoding and Enhanced RTMP audio formats
/// (Opus, FLAC, AC-3, E-AC-3) via FourCC signaling.
///
/// These methods produce only the tag body bytes — the RTMP chunk layer
/// handles the message header (type, size, timestamp).
public enum FLVAudioTag: Sendable {

    // MARK: - Legacy AAC (SoundFormat = 10)

    /// Build AAC sequence header tag body (AudioSpecificConfig).
    ///
    /// Byte 0: `[SoundFormat=10:4][SoundRate=3:2][SoundSize=1:1][SoundType=1:1]` = 0xAF
    /// Byte 1: AACPacketType = 0 (sequence header)
    /// Byte 2+: AudioSpecificConfig data
    ///
    /// - Parameter audioSpecificConfig: The AudioSpecificConfig bytes.
    /// - Returns: The tag body bytes.
    public static func aacSequenceHeader(_ audioSpecificConfig: [UInt8]) -> [UInt8] {
        [0xAF, 0x00] + audioSpecificConfig
    }

    /// Build AAC raw frame tag body.
    ///
    /// Byte 0: 0xAF (AAC, 44.1kHz, 16-bit, stereo)
    /// Byte 1: AACPacketType = 1 (raw AAC frame)
    /// Byte 2+: Raw AAC frame data
    ///
    /// - Parameter data: The raw AAC frame data.
    /// - Returns: The tag body bytes.
    public static func aacRawFrame(_ data: [UInt8]) -> [UInt8] {
        [0xAF, 0x01] + data
    }

    // MARK: - Enhanced RTMP Audio

    /// Build Enhanced RTMP audio sequence start.
    ///
    /// Byte 0: `[isExHeader=1:1][AudioPacketType=0:4][ChannelOrder=0:1][reserved=0:2]`
    /// Bytes 1-4: FourCC
    /// Byte 5+: Codec config data
    ///
    /// - Parameters:
    ///   - fourCC: The audio codec FourCC identifier.
    ///   - config: The codec configuration data.
    /// - Returns: The tag body bytes.
    public static func enhancedSequenceStart(fourCC: FourCC, config: [UInt8]) -> [UInt8] {
        let header = buildEnhancedByte0(packetType: ExAudioPacketType.sequenceStart.rawValue)
        return [header] + fourCC.encode() + config
    }

    /// Build Enhanced RTMP audio coded frame.
    ///
    /// Byte 0: `[isExHeader=1:1][AudioPacketType=1:4][ChannelOrder=0:1][reserved=0:2]`
    /// Bytes 1-4: FourCC
    /// Byte 5+: Audio frame data
    ///
    /// - Parameters:
    ///   - fourCC: The audio codec FourCC identifier.
    ///   - data: The audio frame data.
    /// - Returns: The tag body bytes.
    public static func enhancedCodedFrame(fourCC: FourCC, data: [UInt8]) -> [UInt8] {
        let header = buildEnhancedByte0(packetType: ExAudioPacketType.codedFrames.rawValue)
        return [header] + fourCC.encode() + data
    }

    /// Build Enhanced RTMP audio sequence end.
    ///
    /// - Parameter fourCC: The audio codec FourCC identifier.
    /// - Returns: The tag body bytes.
    public static func enhancedSequenceEnd(fourCC: FourCC) -> [UInt8] {
        let header = buildEnhancedByte0(packetType: ExAudioPacketType.sequenceEnd.rawValue)
        return [header] + fourCC.encode()
    }

    // MARK: - Private

    /// Build enhanced audio byte 0: `[1:1][packetType:4][channelOrder:1][reserved:2]`.
    private static func buildEnhancedByte0(
        packetType: UInt8,
        channelOrder: UInt8 = 0
    ) -> UInt8 {
        0x80 | ((packetType & 0x0F) << 3) | ((channelOrder & 0x01) << 2)
    }
}
