// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Per-chunk-stream-ID state for header compression.
///
/// Both ``ChunkAssembler`` and ``ChunkDisassembler`` maintain one
/// `ChunkStream` per active CSID to resolve delta-compressed headers
/// (fmt 1/2/3) and to buffer partial message payloads during assembly.
struct ChunkStream: Sendable {
    /// The chunk stream ID.
    let chunkStreamID: UInt32

    /// Last absolute timestamp (resolved, not delta).
    var lastTimestamp: UInt32 = 0

    /// Last timestamp delta (used by fmt 3 continuation).
    var lastTimestampDelta: UInt32 = 0

    /// Last message length.
    var lastMessageLength: UInt32 = 0

    /// Last message type ID.
    var lastMessageTypeID: UInt8 = 0

    /// Last message stream ID.
    var lastMessageStreamID: UInt32 = 0

    /// Whether the last chunk used an extended timestamp.
    var lastHadExtendedTimestamp: Bool = false

    /// Buffer for a partially received message (assembler only).
    var pendingPayload: [UInt8] = []

    /// Expected total length of the pending message.
    var pendingMessageLength: UInt32 = 0

    /// Timestamp of the pending message being assembled.
    var pendingTimestamp: UInt32 = 0

    /// Creates a new chunk stream state.
    ///
    /// - Parameter chunkStreamID: The chunk stream ID.
    init(chunkStreamID: UInt32) {
        self.chunkStreamID = chunkStreamID
    }

    /// Updates state from a fully resolved chunk header.
    ///
    /// - Parameter header: The parsed and resolved chunk header.
    mutating func updateFromHeader(_ header: ChunkHeader) {
        lastTimestamp = header.timestamp
        lastMessageLength = header.messageLength
        lastMessageTypeID = header.messageTypeID
        lastMessageStreamID = header.messageStreamID
        lastHadExtendedTimestamp = header.hasExtendedTimestamp
    }

    /// Updates state with a timestamp delta.
    ///
    /// - Parameter delta: The timestamp delta value.
    mutating func updateDelta(_ delta: UInt32) {
        lastTimestampDelta = delta
    }

    /// Whether a message is currently being assembled on this stream.
    var hasPendingMessage: Bool {
        !pendingPayload.isEmpty
    }

    /// Resets the pending payload buffer.
    mutating func clearPending() {
        pendingPayload.removeAll()
        pendingMessageLength = 0
        pendingTimestamp = 0
    }

    /// Resets all state for this chunk stream.
    mutating func reset() {
        lastTimestamp = 0
        lastTimestampDelta = 0
        lastMessageLength = 0
        lastMessageTypeID = 0
        lastMessageStreamID = 0
        lastHadExtendedTimestamp = false
        clearPending()
    }
}
