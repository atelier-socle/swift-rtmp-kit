// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Enhanced RTMP video packet types.
public enum ExVideoPacketType: UInt8, Sendable {
    /// Decoder configuration record (sequence header).
    case sequenceStart = 0
    /// Coded video frames with CTS.
    case codedFrames = 1
    /// End of sequence.
    case sequenceEnd = 2
    /// Coded video frames without CTS.
    case codedFramesX = 3
    /// Video metadata.
    case metadata = 4
    /// MPEG-2 TS sequence start.
    case mpeg2TSSequenceStart = 5
}

/// Video frame types (shared between legacy and enhanced).
public enum VideoFrameType: UInt8, Sendable {
    /// Keyframe (IDR for AVC/HEVC).
    case keyFrame = 1
    /// Inter frame (P-frame).
    case interFrame = 2
    /// Disposable inter frame.
    case disposableInterFrame = 3
    /// Video info/command frame.
    case commandFrame = 5
}

/// Enhanced RTMP video header (ex-header format).
///
/// When the isExHeader bit is set, the video tag uses FourCC signaling
/// instead of legacy codec IDs.
///
/// Byte 0 layout: `[isExHeader=1:1][FrameType:3][PacketType:4]`
public struct ExVideoHeader: Sendable, Equatable {

    /// Video packet type.
    public var packetType: ExVideoPacketType

    /// Frame type (keyframe, inter, etc.).
    public var frameType: VideoFrameType

    /// FourCC codec identifier.
    public var fourCC: FourCC

    /// Creates an enhanced video header.
    ///
    /// - Parameters:
    ///   - packetType: The video packet type.
    ///   - frameType: The frame type.
    ///   - fourCC: The codec FourCC identifier.
    public init(
        packetType: ExVideoPacketType,
        frameType: VideoFrameType,
        fourCC: FourCC
    ) {
        self.packetType = packetType
        self.frameType = frameType
        self.fourCC = fourCC
    }

    /// Encode the ex-header prefix bytes (1 byte header + 4 bytes FourCC).
    ///
    /// - Returns: A 5-byte array.
    public func encode() -> [UInt8] {
        let byte0: UInt8 =
            0x80
            | ((frameType.rawValue & 0x07) << 4)
            | (packetType.rawValue & 0x0F)
        return [byte0] + fourCC.encode()
    }

    /// Decode from bytes (reads byte 0 for flags + 4 bytes FourCC).
    ///
    /// - Parameter bytes: At least 5 bytes.
    /// - Returns: The decoded ex-video header.
    /// - Throws: `FLVError` on insufficient data or invalid values.
    public static func decode(from bytes: [UInt8]) throws -> ExVideoHeader {
        guard bytes.count >= 5 else {
            throw FLVError.truncatedData(expected: 5, actual: bytes.count)
        }
        let byte0 = bytes[0]
        let ftRaw = (byte0 >> 4) & 0x07
        let ptRaw = byte0 & 0x0F
        guard let pt = ExVideoPacketType(rawValue: ptRaw) else {
            throw FLVError.invalidFormat("Unknown video packet type: \(ptRaw)")
        }
        guard let ft = VideoFrameType(rawValue: ftRaw) else {
            throw FLVError.invalidFormat("Unknown frame type: \(ftRaw)")
        }
        let fcc = try FourCC.decode(from: Array(bytes[1..<5]))
        return ExVideoHeader(packetType: pt, frameType: ft, fourCC: fcc)
    }

    /// Check if byte 0 indicates an enhanced RTMP video tag.
    ///
    /// - Parameter byte: The first byte of the video tag body.
    /// - Returns: `true` if the isExHeader bit (bit 7) is set.
    public static func isExHeader(_ byte: UInt8) -> Bool {
        (byte & 0x80) != 0
    }
}
