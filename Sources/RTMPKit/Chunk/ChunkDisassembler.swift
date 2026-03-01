// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Splits RTMP messages into chunks for sending.
///
/// The disassembler handles chunk size limits and fmt selection.
/// For the first chunk of each message, it uses fmt 0 (full header).
/// Continuation chunks use fmt 3 (zero-length message header).
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
    /// The first chunk uses fmt 0 (full header). If the message payload
    /// exceeds ``chunkSize``, subsequent continuation chunks use fmt 3.
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
        var buffer: [UInt8] = []
        let payloadSize = message.payload.count
        buffer.reserveCapacity(payloadSize + 18)

        let firstHeader = ChunkHeader(
            format: .full,
            chunkStreamID: csid,
            timestamp: message.timestamp,
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
                timestamp: message.timestamp,
                messageLength: UInt32(payloadSize),
                messageTypeID: message.typeID,
                messageStreamID: message.streamID
            )
            buffer.append(contentsOf: contHeader.serialize())
            let remaining = payloadSize - offset
            let thisChunkSize = min(cs, remaining)
            buffer.append(contentsOf: message.payload[offset..<(offset + thisChunkSize)])
            offset += thisChunkSize
        }

        updateStreamState(csid: csid, header: firstHeader)
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

    private mutating func updateStreamState(csid: UInt32, header: ChunkHeader) {
        if streams[csid] == nil {
            streams[csid] = ChunkStream(chunkStreamID: csid)
        }
        streams[csid]?.updateFromHeader(header)
        streams[csid]?.updateDelta(header.timestamp)
    }
}
