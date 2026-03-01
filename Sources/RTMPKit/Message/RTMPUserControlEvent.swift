// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// RTMP user control events (message type 4).
///
/// Carried in RTMP messages with type ID 4. The payload begins with
/// a 16-bit big-endian event type followed by event-specific data.
public enum RTMPUserControlEvent: Sendable, Equatable {

    /// Server notifies that a stream has become functional (event 0).
    case streamBegin(streamID: UInt32)

    /// Server notifies that playback of a stream has ended (event 1).
    case streamEOF(streamID: UInt32)

    /// Server notifies that there is no more data on a stream (event 2).
    case streamDry(streamID: UInt32)

    /// Client notifies the server of the buffer size in ms (event 3).
    case setBufferLength(streamID: UInt32, bufferLengthMs: UInt32)

    /// Server sends a ping to check client liveness (event 6).
    case pingRequest(timestamp: UInt32)

    /// Client responds to a ping request (event 7).
    case pingResponse(timestamp: UInt32)

    /// Message type ID (always 4 for user control events).
    public static let typeID: UInt8 = 4

    /// Event type ID.
    public var eventTypeID: UInt16 {
        switch self {
        case .streamBegin: 0
        case .streamEOF: 1
        case .streamDry: 2
        case .setBufferLength: 3
        case .pingRequest: 6
        case .pingResponse: 7
        }
    }

    /// Encode to binary payload (including event type prefix).
    ///
    /// - Returns: The encoded bytes for the message payload.
    public func encode() -> [UInt8] {
        var bytes = encodeUInt16BE(eventTypeID)
        switch self {
        case .streamBegin(let streamID),
            .streamEOF(let streamID),
            .streamDry(let streamID):
            bytes.append(contentsOf: encodeUInt32BE(streamID))
        case .setBufferLength(let streamID, let bufferLengthMs):
            bytes.append(contentsOf: encodeUInt32BE(streamID))
            bytes.append(contentsOf: encodeUInt32BE(bufferLengthMs))
        case .pingRequest(let timestamp),
            .pingResponse(let timestamp):
            bytes.append(contentsOf: encodeUInt32BE(timestamp))
        }
        return bytes
    }

    /// Decode from binary payload.
    ///
    /// - Parameter payload: The binary payload bytes (including event type).
    /// - Returns: The decoded user control event.
    /// - Throws: `MessageError` on unknown event or truncated payload.
    public static func decode(from payload: [UInt8]) throws -> RTMPUserControlEvent {
        guard payload.count >= 2 else {
            throw MessageError.truncatedPayload(expected: 2, actual: payload.count)
        }
        let eventType = decodeUInt16BE(payload)
        switch eventType {
        case 0, 1, 2:
            return try decodeStreamEvent(eventType, payload: payload)
        case 3:
            return try decodeBufferLength(payload)
        case 6, 7:
            return try decodePing(eventType, payload: payload)
        default:
            throw MessageError.unknownEventType(eventType)
        }
    }

    private static func decodeStreamEvent(
        _ eventType: UInt16,
        payload: [UInt8]
    ) throws -> RTMPUserControlEvent {
        guard payload.count >= 6 else {
            throw MessageError.truncatedPayload(expected: 6, actual: payload.count)
        }
        let streamID = decodeUInt32BE(Array(payload[2...]))
        switch eventType {
        case 0: return .streamBegin(streamID: streamID)
        case 1: return .streamEOF(streamID: streamID)
        default: return .streamDry(streamID: streamID)
        }
    }

    private static func decodeBufferLength(_ payload: [UInt8]) throws -> RTMPUserControlEvent {
        guard payload.count >= 10 else {
            throw MessageError.truncatedPayload(expected: 10, actual: payload.count)
        }
        let streamID = decodeUInt32BE(Array(payload[2...]))
        let bufferLength = decodeUInt32BE(Array(payload[6...]))
        return .setBufferLength(streamID: streamID, bufferLengthMs: bufferLength)
    }

    private static func decodePing(
        _ eventType: UInt16,
        payload: [UInt8]
    ) throws -> RTMPUserControlEvent {
        guard payload.count >= 6 else {
            throw MessageError.truncatedPayload(expected: 6, actual: payload.count)
        }
        let timestamp = decodeUInt32BE(Array(payload[2...]))
        return eventType == 6
            ? .pingRequest(timestamp: timestamp)
            : .pingResponse(timestamp: timestamp)
    }
}

// MARK: - Private Helpers

private func encodeUInt16BE(_ value: UInt16) -> [UInt8] {
    [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
}

private func decodeUInt16BE(_ bytes: [UInt8]) -> UInt16 {
    UInt16(bytes[0]) << 8 | UInt16(bytes[1])
}

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
