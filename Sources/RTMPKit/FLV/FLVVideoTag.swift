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

    // MARK: - Configuration Record Builders

    /// Builds an AVCDecoderConfigurationRecord (ISO 14496-15 §5.3.3.1) from raw
    /// SPS and PPS NAL unit bytes.
    ///
    /// The record is suitable for passing to ``avcSequenceHeader(_:)`` or
    /// ``enhancedSequenceStart(fourCC:config:)`` with ``FourCC/mp4a``.
    ///
    /// Layout:
    /// ```
    /// configurationVersion   = 1
    /// AVCProfileIndication   = sps[1]
    /// profile_compatibility  = sps[2]
    /// AVCLevelIndication     = sps[3]
    /// lengthSizeMinusOne     = 3   (4-byte NALU lengths)
    /// numOfSPS               = 1
    /// spsLength              (UInt16 BE)
    /// spsData
    /// numOfPPS               = 1
    /// ppsLength              (UInt16 BE)
    /// ppsData
    /// ```
    ///
    /// - Parameters:
    ///   - sps: Sequence Parameter Set NAL unit bytes (without start codes).
    ///   - pps: Picture Parameter Set NAL unit bytes (without start codes).
    /// - Returns: The AVCDecoderConfigurationRecord bytes.
    public static func buildAVCDecoderConfigurationRecord(
        sps: [UInt8],
        pps: [UInt8]
    ) -> [UInt8] {
        var record: [UInt8] = []
        // configurationVersion
        record.append(0x01)
        // AVCProfileIndication, profile_compatibility, AVCLevelIndication
        record.append(sps.count > 1 ? sps[1] : 0x00)
        record.append(sps.count > 2 ? sps[2] : 0x00)
        record.append(sps.count > 3 ? sps[3] : 0x00)
        // lengthSizeMinusOne = 3 (4-byte NALUs) | reserved 6 bits = 0xFF
        record.append(0xFF)
        // numOfSequenceParameterSets = 1 | reserved 3 bits = 0xE1
        record.append(0xE1)
        // SPS length (UInt16 BE)
        record.append(UInt8((sps.count >> 8) & 0xFF))
        record.append(UInt8(sps.count & 0xFF))
        // SPS data
        record.append(contentsOf: sps)
        // numOfPictureParameterSets = 1
        record.append(0x01)
        // PPS length (UInt16 BE)
        record.append(UInt8((pps.count >> 8) & 0xFF))
        record.append(UInt8(pps.count & 0xFF))
        // PPS data
        record.append(contentsOf: pps)
        return record
    }

    /// Builds an HEVCDecoderConfigurationRecord (ISO 14496-15 §8.3.3.1) from raw
    /// VPS, SPS and PPS NAL unit bytes.
    ///
    /// The record is suitable for passing to
    /// ``enhancedSequenceStart(fourCC:config:)`` with ``FourCC/hevc``.
    ///
    /// This builds a minimal record with the three essential parameter set arrays.
    /// Fields that require deep SPS parsing (min/max spatial segmentation, parallelism,
    /// chroma/bit-depth) are set to zero, which is valid per the spec and accepted by
    /// all major RTMP servers (MediaMTX, nginx-rtmp, Wowza, SRS).
    ///
    /// - Parameters:
    ///   - vps: Video Parameter Set NAL unit bytes (without start codes).
    ///   - sps: Sequence Parameter Set NAL unit bytes (without start codes).
    ///   - pps: Picture Parameter Set NAL unit bytes (without start codes).
    /// - Returns: The HEVCDecoderConfigurationRecord bytes.
    public static func buildHEVCDecoderConfigurationRecord(
        vps: [UInt8],
        sps: [UInt8],
        pps: [UInt8]
    ) -> [UInt8] {
        var record: [UInt8] = []

        // --- 23-byte fixed header ---
        // configurationVersion = 1
        record.append(0x01)
        // general_profile_space(2) | general_tier_flag(1) | general_profile_idc(5)
        record.append(sps.count > 1 ? sps[1] : 0x00)
        // general_profile_compatibility_flags (4 bytes)
        record.append(sps.count > 2 ? sps[2] : 0x00)
        record.append(sps.count > 3 ? sps[3] : 0x00)
        record.append(sps.count > 4 ? sps[4] : 0x00)
        record.append(sps.count > 5 ? sps[5] : 0x00)
        // general_constraint_indicator_flags (6 bytes)
        for i in 6...11 {
            record.append(sps.count > i ? sps[i] : 0x00)
        }
        // general_level_idc
        record.append(sps.count > 12 ? sps[12] : 0x00)
        // min_spatial_segmentation_idc (12 bits) with 4 reserved bits = 0xF000
        record.append(0xF0)
        record.append(0x00)
        // parallelismType (2 bits) with 6 reserved bits = 0xFC
        record.append(0xFC)
        // chromaFormat (2 bits) with 6 reserved bits = 0xFC
        record.append(0xFC)
        // bitDepthLumaMinus8 (3 bits) with 5 reserved bits = 0xF8
        record.append(0xF8)
        // bitDepthChromaMinus8 (3 bits) with 5 reserved bits = 0xF8
        record.append(0xF8)
        // avgFrameRate = 0 (unknown)
        record.append(0x00)
        record.append(0x00)
        // constantFrameRate(2) | numTemporalLayers(3) | temporalIdNested(1) | lengthSizeMinusOne(2)
        // = 0b00_001_1_11 = 0x0F  (1 temporal layer, nested, 4-byte NALUs)
        record.append(0x0F)
        // numOfArrays = 3 (VPS, SPS, PPS)
        record.append(0x03)

        // --- VPS array ---
        // array_completeness(1) | reserved(1) | NAL_unit_type(6) = 0x20 (VPS=32)
        record.append(0x20)
        appendNALUArray(to: &record, nalu: vps)

        // --- SPS array ---
        // NAL_unit_type = 0x21 (SPS=33)
        record.append(0x21)
        appendNALUArray(to: &record, nalu: sps)

        // --- PPS array ---
        // NAL_unit_type = 0x22 (PPS=34)
        record.append(0x22)
        appendNALUArray(to: &record, nalu: pps)

        return record
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

    /// Append a single-entry NALU array: numNalus(UInt16 BE) + naluLength(UInt16 BE) + data.
    private static func appendNALUArray(to record: inout [UInt8], nalu: [UInt8]) {
        // numNalus = 1
        record.append(0x00)
        record.append(0x01)
        // naluLength (UInt16 BE)
        record.append(UInt8((nalu.count >> 8) & 0xFF))
        record.append(UInt8(nalu.count & 0xFF))
        // naluData
        record.append(contentsOf: nalu)
    }
}
