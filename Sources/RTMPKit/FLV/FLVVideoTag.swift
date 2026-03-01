// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Builds FLV video tag bodies for RTMP video messages.
///
/// Supports legacy AVC (H.264) encoding and Enhanced RTMP video formats
/// (HEVC, AV1, VP9) via FourCC signaling.
///
/// These methods produce only the tag body bytes — the RTMP chunk layer
/// handles the message header (type, size, timestamp).
public enum FLVVideoTag: Sendable {

    // MARK: - Legacy AVC (CodecID = 7)

    /// Build AVC sequence header tag body (AVCDecoderConfigurationRecord).
    ///
    /// Byte 0: `[FrameType=1:4][CodecID=7:4]` = 0x17
    /// Byte 1: AVCPacketType = 0 (sequence header)
    /// Bytes 2-4: CTS = 0
    /// Byte 5+: AVCDecoderConfigurationRecord
    ///
    /// - Parameter decoderConfigRecord: The AVCDecoderConfigurationRecord bytes.
    /// - Returns: The tag body bytes.
    public static func avcSequenceHeader(_ decoderConfigRecord: [UInt8]) -> [UInt8] {
        [0x17, 0x00, 0x00, 0x00, 0x00] + decoderConfigRecord
    }

    /// Build AVC NALU tag body.
    ///
    /// Byte 0: `[FrameType:4][CodecID=7:4]`
    /// Byte 1: AVCPacketType = 1 (NALU)
    /// Bytes 2-4: CompositionTimeOffset (CTS, signed 24-bit, big-endian)
    /// Byte 5+: NALU data
    ///
    /// - Parameters:
    ///   - data: The NALU data.
    ///   - isKeyframe: Whether this is a keyframe (IDR).
    ///   - cts: Composition time offset (default 0).
    /// - Returns: The tag body bytes.
    public static func avcNALU(
        _ data: [UInt8],
        isKeyframe: Bool,
        cts: Int32 = 0
    ) -> [UInt8] {
        let frameType: UInt8 = isKeyframe ? 0x10 : 0x20
        let byte0 = frameType | 0x07
        return [byte0, 0x01] + encodeCTS(cts) + data
    }

    /// Build AVC end of sequence tag body.
    ///
    /// Byte 0: `[FrameType=1:4][CodecID=7:4]` = 0x17
    /// Byte 1: AVCPacketType = 2 (end of sequence)
    /// Bytes 2-4: CTS = 0
    ///
    /// - Returns: The tag body bytes.
    public static func avcEndOfSequence() -> [UInt8] {
        [0x17, 0x02, 0x00, 0x00, 0x00]
    }

    // MARK: - Enhanced RTMP Video

    /// Build Enhanced RTMP video sequence start.
    ///
    /// Byte 0: `[isExHeader=1:1][PacketType=0:3][FrameType=1:4]`
    /// Bytes 1-4: FourCC
    /// Byte 5+: DecoderConfigurationRecord
    ///
    /// - Parameters:
    ///   - fourCC: The video codec FourCC identifier.
    ///   - config: The decoder configuration record bytes.
    /// - Returns: The tag body bytes.
    public static func enhancedSequenceStart(fourCC: FourCC, config: [UInt8]) -> [UInt8] {
        let byte0 = buildEnhancedByte0(
            packetType: ExVideoPacketType.sequenceStart.rawValue,
            frameType: VideoFrameType.keyFrame.rawValue
        )
        return [byte0] + fourCC.encode() + config
    }

    /// Build Enhanced RTMP video coded frames (WITH CTS — for HEVC).
    ///
    /// Byte 0: `[isExHeader=1:1][PacketType=1:3][FrameType:4]`
    /// Bytes 1-4: FourCC
    /// Bytes 5-7: CTS (signed 24-bit, big-endian)
    /// Byte 8+: Coded data
    ///
    /// - Parameters:
    ///   - fourCC: The video codec FourCC identifier.
    ///   - data: The coded video data.
    ///   - isKeyframe: Whether this is a keyframe.
    ///   - cts: Composition time offset (default 0).
    /// - Returns: The tag body bytes.
    public static func enhancedCodedFrames(
        fourCC: FourCC,
        data: [UInt8],
        isKeyframe: Bool,
        cts: Int32 = 0
    ) -> [UInt8] {
        let ft: UInt8 =
            isKeyframe
            ? VideoFrameType.keyFrame.rawValue
            : VideoFrameType.interFrame.rawValue
        let byte0 = buildEnhancedByte0(
            packetType: ExVideoPacketType.codedFrames.rawValue,
            frameType: ft
        )
        return [byte0] + fourCC.encode() + encodeCTS(cts) + data
    }

    /// Build Enhanced RTMP video coded frames (NO CTS — for AV1).
    ///
    /// Byte 0: `[isExHeader=1:1][PacketType=3:3][FrameType:4]`
    /// Bytes 1-4: FourCC
    /// Byte 5+: Coded data (no CTS field)
    ///
    /// - Parameters:
    ///   - fourCC: The video codec FourCC identifier.
    ///   - data: The coded video data.
    ///   - isKeyframe: Whether this is a keyframe.
    /// - Returns: The tag body bytes.
    public static func enhancedCodedFramesX(
        fourCC: FourCC,
        data: [UInt8],
        isKeyframe: Bool
    ) -> [UInt8] {
        let ft: UInt8 =
            isKeyframe
            ? VideoFrameType.keyFrame.rawValue
            : VideoFrameType.interFrame.rawValue
        let byte0 = buildEnhancedByte0(
            packetType: ExVideoPacketType.codedFramesX.rawValue,
            frameType: ft
        )
        return [byte0] + fourCC.encode() + data
    }

    /// Build Enhanced RTMP video sequence end.
    ///
    /// - Parameter fourCC: The video codec FourCC identifier.
    /// - Returns: The tag body bytes.
    public static func enhancedSequenceEnd(fourCC: FourCC) -> [UInt8] {
        let byte0 = buildEnhancedByte0(
            packetType: ExVideoPacketType.sequenceEnd.rawValue,
            frameType: VideoFrameType.keyFrame.rawValue
        )
        return [byte0] + fourCC.encode()
    }

    // MARK: - Private

    /// Build enhanced video byte 0: `[1:1][packetType:3][frameType:4]`.
    private static func buildEnhancedByte0(packetType: UInt8, frameType: UInt8) -> UInt8 {
        0x80 | ((packetType & 0x07) << 4) | (frameType & 0x0F)
    }

    /// Encode a signed 24-bit CTS value to 3 bytes (big-endian).
    private static func encodeCTS(_ cts: Int32) -> [UInt8] {
        let value = UInt32(bitPattern: cts)
        return [
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }
}
