// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Enhanced RTMP audio packet types.
public enum ExAudioPacketType: UInt8, Sendable {
    /// Codec configuration (sequence header).
    case sequenceStart = 0
    /// Coded audio frames.
    case codedFrames = 1
    /// End of sequence.
    case sequenceEnd = 2
    /// Multichannel configuration.
    case multichannelConfig = 4
    /// Multitrack audio.
    case multitrack = 5
}

/// Enhanced RTMP audio header (ex-header format).
///
/// When the isExHeader bit is set, the audio tag uses FourCC signaling
/// instead of legacy SoundFormat values.
///
/// Byte 0 layout: `[isExHeader=1:1][AudioPacketType:4][ChannelOrder:1][reserved:2]`
public struct ExAudioHeader: Sendable, Equatable {

    /// Audio packet type.
    public var packetType: ExAudioPacketType

    /// Channel ordering (0 = unspecified, 1 = native order).
    public var channelOrder: UInt8

    /// FourCC codec identifier.
    public var fourCC: FourCC

    /// Creates an enhanced audio header.
    ///
    /// - Parameters:
    ///   - packetType: The audio packet type.
    ///   - channelOrder: Channel ordering (default 0).
    ///   - fourCC: The codec FourCC identifier.
    public init(
        packetType: ExAudioPacketType,
        channelOrder: UInt8 = 0,
        fourCC: FourCC
    ) {
        self.packetType = packetType
        self.channelOrder = channelOrder
        self.fourCC = fourCC
    }

    /// Encode the ex-header prefix bytes (1 byte header + 4 bytes FourCC).
    ///
    /// - Returns: A 5-byte array.
    public func encode() -> [UInt8] {
        let byte0: UInt8 =
            0x80
            | ((packetType.rawValue & 0x0F) << 3)
            | ((channelOrder & 0x01) << 2)
        return [byte0] + fourCC.encode()
    }

    /// Decode from bytes (reads byte 0 for flags + 4 bytes FourCC).
    ///
    /// - Parameter bytes: At least 5 bytes.
    /// - Returns: The decoded ex-audio header.
    /// - Throws: `FLVError` on insufficient data or invalid values.
    public static func decode(from bytes: [UInt8]) throws -> ExAudioHeader {
        guard bytes.count >= 5 else {
            throw FLVError.truncatedData(expected: 5, actual: bytes.count)
        }
        let byte0 = bytes[0]
        let ptRaw = (byte0 >> 3) & 0x0F
        let co = (byte0 >> 2) & 0x01
        guard let pt = ExAudioPacketType(rawValue: ptRaw) else {
            throw FLVError.invalidFormat("Unknown audio packet type: \(ptRaw)")
        }
        let fcc = try FourCC.decode(from: Array(bytes[1..<5]))
        return ExAudioHeader(packetType: pt, channelOrder: co, fourCC: fcc)
    }

    /// Check if byte 0 indicates an enhanced RTMP audio tag.
    ///
    /// - Parameter byte: The first byte of the audio tag body.
    /// - Returns: `true` if the isExHeader bit (bit 7) is set.
    public static func isExHeader(_ byte: UInt8) -> Bool {
        (byte & 0x80) != 0
    }
}
