// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Reorders audio and video RTMP messages by timestamp before sending.
///
/// Without interleaving, audio and video packets go out in caller order,
/// which can diverge from timestamp order and cause A/V desynchronisation
/// on the receiver. The interleaver holds a small buffer and flushes
/// messages in ascending timestamp order once both streams have advanced
/// past the earliest buffered timestamp.
///
/// Only audio (type 8) and video (type 9) messages are buffered.
/// Control messages bypass the interleaver entirely.
struct AVInterleaver: Sendable {

    /// A buffered message awaiting send.
    struct Entry: Sendable {
        let message: RTMPMessage
        let chunkStreamID: ChunkStreamID
    }

    /// Pending entries sorted by timestamp.
    private var buffer: [Entry] = []

    /// Highest audio timestamp seen so far.
    private var latestAudioTimestamp: UInt32?

    /// Highest video timestamp seen so far.
    private var latestVideoTimestamp: UInt32?

    /// Maximum entries before force-flushing everything.
    private let maxBufferSize: Int

    /// Creates an interleaver.
    ///
    /// - Parameter maxBufferSize: Force-flush threshold (default: 8).
    init(maxBufferSize: Int = 8) {
        self.maxBufferSize = maxBufferSize
    }

    /// Enqueue a message and return all entries that are safe to send now.
    ///
    /// Messages are returned in ascending timestamp order. An entry is
    /// flushed when its timestamp is ≤ min(latestAudio, latestVideo),
    /// meaning both streams have moved past it.
    ///
    /// - Parameters:
    ///   - message: The RTMP message.
    ///   - chunkStreamID: The chunk stream to send on.
    /// - Returns: Zero or more entries to send, in timestamp order.
    mutating func enqueue(
        message: RTMPMessage, chunkStreamID: ChunkStreamID
    ) -> [Entry] {
        // Track per-stream high-water mark.
        if message.typeID == RTMPMessage.typeIDAudio {
            latestAudioTimestamp = max(
                latestAudioTimestamp ?? 0, message.timestamp
            )
        } else {
            latestVideoTimestamp = max(
                latestVideoTimestamp ?? 0, message.timestamp
            )
        }

        // Insert keeping sorted order (buffer is small, linear insert is fine).
        let entry = Entry(message: message, chunkStreamID: chunkStreamID)
        let idx =
            buffer.firstIndex { $0.message.timestamp > message.timestamp }
            ?? buffer.endIndex
        buffer.insert(entry, at: idx)

        return drain()
    }

    /// Flush all remaining buffered entries (call on disconnect).
    mutating func flushAll() -> [Entry] {
        let result = buffer
        buffer.removeAll()
        latestAudioTimestamp = nil
        latestVideoTimestamp = nil
        return result
    }

    /// Resets all state.
    mutating func reset() {
        buffer.removeAll()
        latestAudioTimestamp = nil
        latestVideoTimestamp = nil
    }

    // MARK: - Private

    /// Number of entries currently buffered.
    var count: Int { buffer.count }

    private mutating func drain() -> [Entry] {
        // Force-flush if buffer grows too large (prevents unbounded memory).
        if buffer.count > maxBufferSize {
            return flushAll()
        }

        // Flush threshold = min of both high-water marks.
        // If only one stream is active, flush immediately (no interleaving needed).
        let threshold: UInt32
        if let a = latestAudioTimestamp, let v = latestVideoTimestamp {
            threshold = min(a, v)
        } else {
            // Single-stream: flush everything.
            let result = buffer
            buffer.removeAll()
            return result
        }

        // Drain all entries with timestamp ≤ threshold.
        let splitIdx =
            buffer.firstIndex { $0.message.timestamp > threshold }
            ?? buffer.endIndex
        guard splitIdx > 0 else { return [] }
        let flushed = Array(buffer[0..<splitIdx])
        buffer.removeFirst(splitIdx)
        return flushed
    }
}

// MARK: - RTMPPublisher Integration

extension RTMPPublisher {

    /// Enqueue an A/V message through the interleaver and send all
    /// entries that are ready (timestamp-ordered).
    internal func sendInterleavedAV(
        _ message: RTMPMessage, chunkStreamID: ChunkStreamID
    ) async throws {
        let entries = interleaver.enqueue(
            message: message, chunkStreamID: chunkStreamID
        )
        for entry in entries {
            try await sendRTMPMessage(
                entry.message, chunkStreamID: entry.chunkStreamID
            )
        }
    }

    /// Flush all remaining interleaved entries (call before disconnect).
    internal func flushInterleaver() async throws {
        let entries = interleaver.flushAll()
        for entry in entries {
            try await sendRTMPMessage(
                entry.message, chunkStreamID: entry.chunkStreamID
            )
        }
    }
}
