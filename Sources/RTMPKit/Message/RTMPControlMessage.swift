// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Bandwidth limit types for Set Peer Bandwidth (type 6).
public enum BandwidthLimitType: UInt8, Sendable {
    /// The peer should limit its output bandwidth to the indicated window size.
    case hard = 0
    /// The peer should limit its output bandwidth to the smaller of the
    /// indicated window size and the existing limit.
    case soft = 1
    /// Treated as hard if previous limit was soft, otherwise ignored.
    case dynamic = 2
}

/// Errors specific to RTMP control message processing.
public enum MessageError: Error, Sendable, Equatable {
    /// Unknown or unsupported message type ID.
    case unknownTypeID(UInt8)
    /// Payload is too short for the expected message format.
    case truncatedPayload(expected: Int, actual: Int)
    /// Invalid bandwidth limit type value.
    case invalidLimitType(UInt8)
    /// Chunk size has MSB set (must be 0).
    case invalidChunkSize(UInt32)
    /// Unknown command name in AMF0 command message.
    case unknownCommand(String)
    /// Unexpected AMF0 value during command decoding.
    case invalidCommandPayload(String)
    /// Unknown user control event type.
    case unknownEventType(UInt16)
    /// Invalid data message format.
    case invalidDataMessage(String)
}

/// RTMP protocol control messages.
///
/// These are low-level protocol messages with fixed binary formats.
/// They always use message stream ID 0 and chunk stream ID 2.
public enum RTMPControlMessage: Sendable, Equatable {

    /// Set the chunk size for subsequent chunks (type 1).
    /// Value: 31 bits (MSB must be 0). Range: 1 to 0x7FFFFFFF.
    case setChunkSize(UInt32)

    /// Abort a partially received message on a chunk stream (type 2).
    case abort(chunkStreamID: UInt32)

    /// Acknowledge bytes received (type 3).
    case acknowledgement(sequenceNumber: UInt32)

    /// Set the window acknowledgement size (type 5).
    case windowAcknowledgementSize(UInt32)

    /// Set peer bandwidth (type 6).
    case setPeerBandwidth(windowSize: UInt32, limitType: BandwidthLimitType)

    /// Message type ID for this control message.
    public var typeID: UInt8 {
        switch self {
        case .setChunkSize: 1
        case .abort: 2
        case .acknowledgement: 3
        case .windowAcknowledgementSize: 5
        case .setPeerBandwidth: 6
        }
    }

    /// Encode to binary payload.
    ///
    /// - Returns: The encoded bytes for the message payload.
    public func encode() -> [UInt8] {
        switch self {
        case .setChunkSize(let size):
            return encodeUInt32BE(size & 0x7FFF_FFFF)
        case .abort(let csid):
            return encodeUInt32BE(csid)
        case .acknowledgement(let seq):
            return encodeUInt32BE(seq)
        case .windowAcknowledgementSize(let size):
            return encodeUInt32BE(size)
        case .setPeerBandwidth(let windowSize, let limitType):
            return encodeUInt32BE(windowSize) + [limitType.rawValue]
        }
    }

    /// Decode from message type ID and binary payload.
    ///
    /// - Parameters:
    ///   - typeID: The RTMP message type ID (1, 2, 3, 5, or 6).
    ///   - payload: The binary payload bytes.
    /// - Returns: The decoded control message.
    /// - Throws: `MessageError` on invalid type or truncated payload.
    public static func decode(
        typeID: UInt8,
        payload: [UInt8]
    ) throws -> RTMPControlMessage {
        switch typeID {
        case 1:
            let value = try readUInt32(from: payload)
            return .setChunkSize(value & 0x7FFF_FFFF)
        case 2:
            return .abort(chunkStreamID: try readUInt32(from: payload))
        case 3:
            return .acknowledgement(sequenceNumber: try readUInt32(from: payload))
        case 5:
            return .windowAcknowledgementSize(try readUInt32(from: payload))
        case 6:
            return try decodePeerBandwidth(payload)
        default:
            throw MessageError.unknownTypeID(typeID)
        }
    }

    private static func readUInt32(from payload: [UInt8]) throws -> UInt32 {
        guard payload.count >= 4 else {
            throw MessageError.truncatedPayload(expected: 4, actual: payload.count)
        }
        return decodeUInt32BE(payload)
    }

    private static func decodePeerBandwidth(_ payload: [UInt8]) throws -> RTMPControlMessage {
        guard payload.count >= 5 else {
            throw MessageError.truncatedPayload(expected: 5, actual: payload.count)
        }
        guard let limitType = BandwidthLimitType(rawValue: payload[4]) else {
            throw MessageError.invalidLimitType(payload[4])
        }
        return .setPeerBandwidth(
            windowSize: decodeUInt32BE(payload),
            limitType: limitType
        )
    }
}

// MARK: - Private Helpers

private func encodeUInt32BE(_ value: UInt32) -> [UInt8] {
    [
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
    ]
}

private func decodeUInt32BE(_ bytes: [UInt8]) -> UInt32 {
    UInt32(bytes[0]) << 24
        | UInt32(bytes[1]) << 16
        | UInt32(bytes[2]) << 8
        | UInt32(bytes[3])
}
