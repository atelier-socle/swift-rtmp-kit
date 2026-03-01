// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// RTMP chunk format types (the 2-bit `fmt` field in the basic header).
///
/// The format determines how many bytes of message header follow the basic
/// header, enabling progressive compression of repeated fields.
public enum ChunkFormat: UInt8, Sendable {
    /// Full header with 11-byte message header.
    ///
    /// Includes timestamp, message length, message type ID, and message stream ID.
    /// Used for the first message on a chunk stream or when the stream ID changes.
    case full = 0

    /// Same-stream header with 7-byte message header.
    ///
    /// Omits message stream ID (reuses previous value on this CSID).
    /// Includes timestamp delta, message length, and message type ID.
    case sameStream = 1

    /// Timestamp-only header with 3-byte message header.
    ///
    /// Only contains the timestamp delta. Message length, type ID, and
    /// stream ID are all reused from the previous chunk on this CSID.
    case timestampOnly = 2

    /// Continuation header with 0-byte message header.
    ///
    /// All fields are inherited from the previous chunk on this CSID.
    /// Used for continuation chunks when a message spans multiple chunks.
    case continuation = 3
}

/// A parsed RTMP chunk header (basic header + message header).
///
/// Chunk headers carry the metadata needed to reassemble messages from
/// chunks. The ``format`` field determines which fields are present
/// on the wire; the remaining fields are resolved from per-CSID state.
public struct ChunkHeader: Sendable, Equatable {
    /// Chunk format type (0, 1, 2, or 3).
    public var format: ChunkFormat

    /// Chunk stream ID (2–65599).
    public var chunkStreamID: UInt32

    /// Timestamp or timestamp delta (depending on format).
    public var timestamp: UInt32

    /// Total message length in bytes.
    public var messageLength: UInt32

    /// RTMP message type ID.
    public var messageTypeID: UInt8

    /// Message stream ID (little-endian in wire format).
    public var messageStreamID: UInt32

    /// Whether this header requires an extended timestamp field.
    ///
    /// When `true`, the 24-bit timestamp/delta field is set to `0xFFFFFF`
    /// and the actual value follows as a 32-bit big-endian integer.
    public var hasExtendedTimestamp: Bool {
        timestamp >= UInt24.max
    }

    /// Creates a new chunk header.
    ///
    /// - Parameters:
    ///   - format: The chunk format type.
    ///   - chunkStreamID: The chunk stream ID.
    ///   - timestamp: The timestamp or timestamp delta.
    ///   - messageLength: The total message length.
    ///   - messageTypeID: The message type ID.
    ///   - messageStreamID: The message stream ID.
    public init(
        format: ChunkFormat,
        chunkStreamID: UInt32,
        timestamp: UInt32 = 0,
        messageLength: UInt32 = 0,
        messageTypeID: UInt8 = 0,
        messageStreamID: UInt32 = 0
    ) {
        self.format = format
        self.chunkStreamID = chunkStreamID
        self.timestamp = timestamp
        self.messageLength = messageLength
        self.messageTypeID = messageTypeID
        self.messageStreamID = messageStreamID
    }
}

// MARK: - Serialization

extension ChunkHeader {
    /// Serializes this chunk header to bytes.
    ///
    /// Writes the basic header (1–3 bytes depending on CSID), followed
    /// by the message header (0–11 bytes depending on format), followed
    /// by an extended timestamp (4 bytes) if needed.
    ///
    /// - Returns: The serialized header bytes.
    public func serialize() -> [UInt8] {
        var buffer: [UInt8] = []
        buffer.reserveCapacity(15)
        serializeBasicHeader(into: &buffer)
        serializeMessageHeader(into: &buffer)
        serializeExtendedTimestamp(into: &buffer)
        return buffer
    }

    private func serializeBasicHeader(into buffer: inout [UInt8]) {
        let fmtBits = format.rawValue << 6
        if chunkStreamID >= 2 && chunkStreamID <= 63 {
            buffer.append(fmtBits | UInt8(chunkStreamID))
        } else if chunkStreamID >= 64 && chunkStreamID <= 319 {
            buffer.append(fmtBits | 0x00)
            buffer.append(UInt8(chunkStreamID - 64))
        } else {
            buffer.append(fmtBits | 0x01)
            let adjusted = chunkStreamID - 64
            buffer.append(UInt8(adjusted & 0xFF))
            buffer.append(UInt8((adjusted >> 8) & 0xFF))
        }
    }

    private func serializeMessageHeader(into buffer: inout [UInt8]) {
        let wireTimestamp = hasExtendedTimestamp ? UInt24.max : timestamp
        switch format {
        case .full:
            UInt24.write(wireTimestamp, to: &buffer)
            UInt24.write(messageLength, to: &buffer)
            buffer.append(messageTypeID)
            writeUInt32LE(messageStreamID, to: &buffer)
        case .sameStream:
            UInt24.write(wireTimestamp, to: &buffer)
            UInt24.write(messageLength, to: &buffer)
            buffer.append(messageTypeID)
        case .timestampOnly:
            UInt24.write(wireTimestamp, to: &buffer)
        case .continuation:
            break
        }
    }

    private func serializeExtendedTimestamp(into buffer: inout [UInt8]) {
        guard hasExtendedTimestamp else { return }
        writeUInt32BE(timestamp, to: &buffer)
    }

    private func writeUInt32BE(_ value: UInt32, to buffer: inout [UInt8]) {
        buffer.append(UInt8((value >> 24) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8(value & 0xFF))
    }

    private func writeUInt32LE(_ value: UInt32, to buffer: inout [UInt8]) {
        buffer.append(UInt8(value & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 24) & 0xFF))
    }
}

// MARK: - Parsing

extension ChunkHeader {
    /// Parses a chunk header from a byte array.
    ///
    /// Reads the basic header, message header, and optional extended
    /// timestamp. Uses per-CSID state from the provided lookup to
    /// resolve delta-compressed fields (fmt 1/2/3).
    ///
    /// - Parameters:
    ///   - bytes: The source byte array.
    ///   - offset: Read position (advanced past the parsed header).
    ///   - previousHeaders: Per-CSID state for resolving delta fields.
    /// - Returns: The parsed header, or `nil` if not enough bytes.
    /// - Throws: ``ChunkError`` on protocol violations.
    public static func parse(
        from bytes: [UInt8],
        offset: inout Int,
        previousHeaders: [UInt32: ChunkHeader]
    ) throws -> ChunkHeader? {
        guard offset < bytes.count else { return nil }
        let startOffset = offset
        guard let (fmt, csid) = parseBasicHeader(from: bytes, offset: &offset) else {
            offset = startOffset
            return nil
        }
        guard
            let header = try parseMessageHeader(
                fmt: fmt,
                csid: csid,
                from: bytes,
                offset: &offset,
                previousHeaders: previousHeaders
            )
        else {
            offset = startOffset
            return nil
        }
        return header
    }

    private static func parseBasicHeader(
        from bytes: [UInt8],
        offset: inout Int
    ) -> (ChunkFormat, UInt32)? {
        guard offset < bytes.count else { return nil }
        let byte0 = bytes[offset]
        offset += 1
        guard let fmt = ChunkFormat(rawValue: byte0 >> 6) else { return nil }
        let csidField = byte0 & 0x3F
        switch csidField {
        case 0:
            guard offset < bytes.count else { return nil }
            let csid = UInt32(bytes[offset]) + 64
            offset += 1
            return (fmt, csid)
        case 1:
            guard offset + 1 < bytes.count else { return nil }
            let csid = UInt32(bytes[offset + 1]) * 256 + UInt32(bytes[offset]) + 64
            offset += 2
            return (fmt, csid)
        default:
            return (fmt, UInt32(csidField))
        }
    }

    private static func parseMessageHeader(
        fmt: ChunkFormat,
        csid: UInt32,
        from bytes: [UInt8],
        offset: inout Int,
        previousHeaders: [UInt32: ChunkHeader]
    ) throws -> ChunkHeader? {
        switch fmt {
        case .full:
            return try parseFmt0(csid: csid, from: bytes, offset: &offset)
        case .sameStream:
            return try parseFmtDelta(
                fmt: fmt, csid: csid, from: bytes, offset: &offset,
                previousHeaders: previousHeaders
            )
        case .timestampOnly:
            return try parseFmtDelta(
                fmt: fmt, csid: csid, from: bytes, offset: &offset,
                previousHeaders: previousHeaders
            )
        case .continuation:
            return try parseFmt3(
                csid: csid, from: bytes, offset: &offset,
                previousHeaders: previousHeaders
            )
        }
    }

    private static func parseFmt0(
        csid: UInt32,
        from bytes: [UInt8],
        offset: inout Int
    ) throws -> ChunkHeader? {
        guard offset + 11 <= bytes.count else { return nil }
        guard let ts = UInt24.read(from: bytes, offset: &offset) else { return nil }
        guard let msgLen = UInt24.read(from: bytes, offset: &offset) else { return nil }
        let typeID = bytes[offset]
        offset += 1
        let streamID = readUInt32LE(from: bytes, offset: &offset)
        var header = ChunkHeader(
            format: .full,
            chunkStreamID: csid,
            timestamp: ts,
            messageLength: msgLen,
            messageTypeID: typeID,
            messageStreamID: streamID
        )
        if ts == UInt24.max {
            guard let extTs = readExtendedTimestamp(from: bytes, offset: &offset) else {
                return nil
            }
            header.timestamp = extTs
        }
        return header
    }

    private static func parseFmtDelta(
        fmt: ChunkFormat,
        csid: UInt32,
        from bytes: [UInt8],
        offset: inout Int,
        previousHeaders: [UInt32: ChunkHeader]
    ) throws -> ChunkHeader? {
        guard let prev = previousHeaders[csid] else {
            throw ChunkError.noPreviousHeader(chunkStreamID: csid)
        }
        let needed = fmt == .sameStream ? 7 : 3
        guard offset + needed <= bytes.count else { return nil }
        guard let tsDelta = UInt24.read(from: bytes, offset: &offset) else { return nil }
        var header = ChunkHeader(
            format: fmt,
            chunkStreamID: csid,
            timestamp: tsDelta,
            messageLength: prev.messageLength,
            messageTypeID: prev.messageTypeID,
            messageStreamID: prev.messageStreamID
        )
        if fmt == .sameStream {
            guard let msgLen = UInt24.read(from: bytes, offset: &offset) else { return nil }
            let typeID = bytes[offset]
            offset += 1
            header.messageLength = msgLen
            header.messageTypeID = typeID
        }
        if tsDelta == UInt24.max {
            guard let extTs = readExtendedTimestamp(from: bytes, offset: &offset) else {
                return nil
            }
            header.timestamp = extTs
        }
        return header
    }

    private static func parseFmt3(
        csid: UInt32,
        from bytes: [UInt8],
        offset: inout Int,
        previousHeaders: [UInt32: ChunkHeader]
    ) throws -> ChunkHeader? {
        guard let prev = previousHeaders[csid] else {
            throw ChunkError.noPreviousHeader(chunkStreamID: csid)
        }
        var header = ChunkHeader(
            format: .continuation,
            chunkStreamID: csid,
            timestamp: prev.timestamp,
            messageLength: prev.messageLength,
            messageTypeID: prev.messageTypeID,
            messageStreamID: prev.messageStreamID
        )
        if prev.hasExtendedTimestamp {
            guard let extTs = readExtendedTimestamp(from: bytes, offset: &offset) else {
                return nil
            }
            header.timestamp = extTs
        }
        return header
    }

    private static func readExtendedTimestamp(
        from bytes: [UInt8],
        offset: inout Int
    ) -> UInt32? {
        guard offset + 4 <= bytes.count else { return nil }
        let value =
            UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
        offset += 4
        return value
    }

    private static func readUInt32LE(from bytes: [UInt8], offset: inout Int) -> UInt32 {
        let value =
            UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
        offset += 4
        return value
    }
}
