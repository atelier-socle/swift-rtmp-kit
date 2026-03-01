// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Reassembles complete RTMP messages from incoming chunk data.
///
/// The assembler maintains per-CSID state to handle delta-compressed
/// headers and multi-chunk messages. Chunks from different CSIDs can
/// be interleaved (multiplexing).
///
/// ## Usage
///
/// ```swift
/// var assembler = ChunkAssembler()
/// let messages = try assembler.process(bytes: incomingData)
/// for msg in messages {
///     handleMessage(msg)
/// }
/// ```
public struct ChunkAssembler: Sendable {
    /// Current receive chunk size (default: 128).
    public var chunkSize: UInt32

    private var streams: [UInt32: ChunkStream] = [:]
    private var previousHeaders: [UInt32: ChunkHeader] = [:]
    private var internalBuffer: [UInt8] = []

    /// Creates a new assembler with the specified chunk size.
    ///
    /// - Parameter chunkSize: Maximum chunk payload size (default: 128).
    public init(chunkSize: UInt32 = 128) {
        self.chunkSize = chunkSize
    }

    /// Processes incoming bytes and returns any complete messages.
    ///
    /// Leftover bytes are buffered internally for the next call.
    /// Returns an empty array if no complete messages can be assembled yet.
    ///
    /// - Parameter bytes: Incoming byte data.
    /// - Returns: Array of complete RTMP messages.
    /// - Throws: ``ChunkError`` on protocol violations.
    public mutating func process(bytes: [UInt8]) throws -> [RTMPMessage] {
        internalBuffer.append(contentsOf: bytes)
        var messages: [RTMPMessage] = []
        while !internalBuffer.isEmpty {
            var offset = 0
            guard
                let header = try ChunkHeader.parse(
                    from: internalBuffer,
                    offset: &offset,
                    previousHeaders: previousHeaders
                )
            else {
                break
            }
            guard
                let message = try processChunk(
                    header: header,
                    from: internalBuffer,
                    offset: &offset
                )
            else {
                break
            }
            internalBuffer.removeFirst(offset)
            if let msg = message {
                messages.append(msg)
            }
        }
        return messages
    }

    /// Updates the receive chunk size.
    ///
    /// Typically called after receiving a Set Chunk Size protocol control message.
    ///
    /// - Parameter size: The new chunk size.
    public mutating func setChunkSize(_ size: UInt32) {
        chunkSize = size
    }

    /// Resets all per-CSID state and clears internal buffers.
    public mutating func reset() {
        streams.removeAll()
        previousHeaders.removeAll()
        internalBuffer.removeAll()
    }

    // MARK: - Private

    private mutating func processChunk(
        header: ChunkHeader,
        from bytes: [UInt8],
        offset: inout Int
    ) throws -> RTMPMessage?? {
        let csid = header.chunkStreamID
        ensureStream(csid)
        let resolved = resolveHeader(header)
        let msgLen = Int(resolved.messageLength)
        let pendingCount = streams[csid]?.pendingPayload.count ?? 0
        let remaining = msgLen - pendingCount
        let chunkPayloadSize = min(Int(chunkSize), remaining)
        guard offset + chunkPayloadSize <= bytes.count else {
            return nil
        }
        let hasPending = streams[csid]?.hasPendingMessage ?? false
        if !hasPending {
            startNewMessage(csid: csid, header: resolved)
        }
        let payloadSlice = bytes[offset..<(offset + chunkPayloadSize)]
        streams[csid]?.pendingPayload.append(contentsOf: payloadSlice)
        offset += chunkPayloadSize
        previousHeaders[csid] = resolved
        updateStreamState(csid: csid, header: resolved)
        let totalReceived = streams[csid]?.pendingPayload.count ?? 0
        if totalReceived >= msgLen {
            let msg = buildMessage(csid: csid)
            return .some(msg)
        }
        return .some(nil)
    }

    private func resolveHeader(_ header: ChunkHeader) -> ChunkHeader {
        var resolved = header
        let csid = header.chunkStreamID
        guard let stream = streams[csid] else { return resolved }
        switch header.format {
        case .full:
            break
        case .sameStream:
            resolved.messageStreamID = stream.lastMessageStreamID
        case .timestampOnly:
            resolved.messageStreamID = stream.lastMessageStreamID
            resolved.messageLength = stream.lastMessageLength
            resolved.messageTypeID = stream.lastMessageTypeID
        case .continuation:
            break
        }
        return resolved
    }

    private mutating func ensureStream(_ csid: UInt32) {
        if streams[csid] == nil {
            streams[csid] = ChunkStream(chunkStreamID: csid)
        }
    }

    private mutating func startNewMessage(csid: UInt32, header: ChunkHeader) {
        streams[csid]?.pendingPayload.removeAll()
        streams[csid]?.pendingMessageLength = header.messageLength
        streams[csid]?.pendingTimestamp = header.timestamp
        streams[csid]?.pendingPayload.reserveCapacity(Int(header.messageLength))
    }

    private mutating func buildMessage(csid: UInt32) -> RTMPMessage {
        let typeID = streams[csid]?.lastMessageTypeID ?? 0
        let streamID = streams[csid]?.lastMessageStreamID ?? 0
        let timestamp = streams[csid]?.pendingTimestamp ?? 0
        let payload = streams[csid]?.pendingPayload ?? []
        let msg = RTMPMessage(
            typeID: typeID,
            streamID: streamID,
            timestamp: timestamp,
            payload: payload
        )
        streams[csid]?.clearPending()
        return msg
    }

    private mutating func updateStreamState(csid: UInt32, header: ChunkHeader) {
        streams[csid]?.updateFromHeader(header)
        if header.format == .full {
            streams[csid]?.updateDelta(header.timestamp)
        } else {
            streams[csid]?.updateDelta(header.timestamp)
        }
    }
}
