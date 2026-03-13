// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Splits RTMP messages into chunks for sending.
///
/// The disassembler handles chunk size limits and fmt selection.
/// It uses header compression per the RTMP specification:
/// - **fmt 0** (full, 11 bytes): first message on a CSID or stream ID change.
/// - **fmt 1** (same-stream, 7 bytes): same stream ID, carries delta + length + type.
/// - **fmt 2** (timestamp-only, 3 bytes): same stream ID, length, and type as previous.
/// - **fmt 3** (continuation, 0 bytes): continuation chunks within a single message.
///
/// ## Usage
///
/// ```swift
/// var disassembler = ChunkDisassembler(chunkSize: 4096)
/// let bytes = disassembler.disassemble(
///     message: message,
///     chunkStreamID: .audio
/// )
/// ```
public struct ChunkDisassembler: Sendable {
    /// Current send chunk size (default: 128).
    public var chunkSize: UInt32

    private var streams: [UInt32: ChunkStream] = [:]

    /// Creates a new disassembler.
    ///
    /// - Parameter chunkSize: Maximum chunk payload size (default: 128).
    public init(chunkSize: UInt32 = 128) {
        self.chunkSize = chunkSize
    }

    /// Splits a message into chunks and returns serialized bytes.
    ///
    /// Selects the most compact chunk header format based on the previous
    /// message sent on the same chunk stream ID, then splits the payload
    /// into ``chunkSize``-bounded chunks.
    ///
    /// - Parameters:
    ///   - message: The RTMP message to split.
    ///   - chunkStreamID: The chunk stream ID to use.
    /// - Returns: Serialized bytes ready for sending.
    public mutating func disassemble(
        message: RTMPMessage,
        chunkStreamID: ChunkStreamID
    ) -> [UInt8] {
        let csid = chunkStreamID.value
        let payloadSize = message.payload.count
        var buffer: [UInt8] = []
        buffer.reserveCapacity(payloadSize + 18)

        let fmt = selectFormat(
            csid: csid, message: message, payloadSize: payloadSize
        )
        let timestampOrDelta: UInt32
        let lastTS = streams[csid]?.lastTimestamp ?? 0
        if fmt == .full || message.timestamp < lastTS {
            timestampOrDelta = message.timestamp
        } else {
            timestampOrDelta = message.timestamp - lastTS
        }

        let firstHeader = ChunkHeader(
            format: fmt,
            chunkStreamID: csid,
            timestamp: timestampOrDelta,
            messageLength: UInt32(payloadSize),
            messageTypeID: message.typeID,
            messageStreamID: message.streamID
        )
        buffer.append(contentsOf: firstHeader.serialize())

        let cs = Int(chunkSize)
        let firstChunkSize = min(cs, payloadSize)
        buffer.append(contentsOf: message.payload[0..<firstChunkSize])

        var offset = firstChunkSize
        while offset < payloadSize {
            let contHeader = ChunkHeader(
                format: .continuation,
                chunkStreamID: csid,
                timestamp: timestampOrDelta,
                messageLength: UInt32(payloadSize),
                messageTypeID: message.typeID,
                messageStreamID: message.streamID
            )
            buffer.append(contentsOf: contHeader.serialize())
            let remaining = payloadSize - offset
            let thisChunkSize = min(cs, remaining)
            buffer.append(
                contentsOf: message.payload[offset..<(offset + thisChunkSize)]
            )
            offset += thisChunkSize
        }

        updateStreamState(
            csid: csid, header: firstHeader,
            absoluteTimestamp: message.timestamp
        )
        return buffer
    }

    /// Updates the send chunk size.
    ///
    /// Affects all subsequent calls to ``disassemble(message:chunkStreamID:)``.
    ///
    /// - Parameter size: The new chunk size.
    public mutating func setChunkSize(_ size: UInt32) {
        chunkSize = size
    }

    /// Resets all per-CSID state (e.g., on reconnect).
    public mutating func reset() {
        streams.removeAll()
    }

    // MARK: - Private

    private func selectFormat(
        csid: UInt32, message: RTMPMessage, payloadSize: Int
    ) -> ChunkFormat {
        guard let prev = streams[csid] else {
            return .full
        }

        // Stream ID changed → must send full header.
        guard prev.lastMessageStreamID == message.streamID else {
            return .full
        }

        // Non-monotonic timestamp → full header (no valid delta).
        // This happens with B-frames (H.264 High profile) where PTS
        // can go backwards relative to the previous message on this CSID.
        guard message.timestamp >= prev.lastTimestamp else {
            return .full
        }

        let sameLength = prev.lastMessageLength == UInt32(payloadSize)
        let sameType = prev.lastMessageTypeID == message.typeID

        // Same stream ID + same length + same type → fmt 2 (timestamp-only).
        if sameLength && sameType {
            return .timestampOnly
        }

        // Same stream ID, but length or type differs → fmt 1 (same-stream).
        return .sameStream
    }

    private mutating func updateStreamState(
        csid: UInt32, header: ChunkHeader, absoluteTimestamp: UInt32
    ) {
        if streams[csid] == nil {
            streams[csid] = ChunkStream(chunkStreamID: csid)
        }
        // Store the absolute timestamp (not the delta) for next comparison.
        var resolved = header
        resolved.timestamp = absoluteTimestamp
        streams[csid]?.updateFromHeader(resolved)
        streams[csid]?.updateDelta(header.timestamp)
    }
}
