// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors that can occur during RTMP chunk processing.
public enum ChunkError: Error, Sendable, Equatable {
    /// A delta-compressed header (fmt 1/2/3) was received on a CSID
    /// that has no previous header state.
    case noPreviousHeader(chunkStreamID: UInt32)

    /// The chunk stream ID is outside the valid range (2–65599).
    case invalidChunkStreamID(UInt32)

    /// The chunk size is outside the valid range (1–0x7FFFFFFF).
    case invalidChunkSize(UInt32)

    /// The received payload exceeded the declared message length.
    case messageLengthExceeded(expected: UInt32, received: Int)
}

// MARK: - CustomStringConvertible

extension ChunkError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .noPreviousHeader(csid):
            return "ChunkError: no previous header for CSID \(csid)"
        case let .invalidChunkStreamID(csid):
            return "ChunkError: invalid chunk stream ID \(csid)"
        case let .invalidChunkSize(size):
            return "ChunkError: invalid chunk size \(size)"
        case let .messageLengthExceeded(expected, received):
            return "ChunkError: message length exceeded (expected \(expected), received \(received))"
        }
    }
}
