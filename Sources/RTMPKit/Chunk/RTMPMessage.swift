// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A complete RTMP message reassembled from chunks.
///
/// This is the unit of communication in the RTMP protocol. Messages are
/// split into chunks for transport and reassembled by the ``ChunkAssembler``.
/// The message type ID determines how the payload should be interpreted
/// (protocol control, command, audio, video, etc.).
public struct RTMPMessage: Sendable, Equatable {
    /// RTMP message type ID.
    public var typeID: UInt8

    /// Message stream ID.
    public var streamID: UInt32

    /// Timestamp in milliseconds.
    public var timestamp: UInt32

    /// Message payload bytes.
    public var payload: [UInt8]

    /// Creates a new RTMP message.
    ///
    /// - Parameters:
    ///   - typeID: The message type ID.
    ///   - streamID: The message stream ID.
    ///   - timestamp: The timestamp in milliseconds.
    ///   - payload: The message payload bytes.
    public init(typeID: UInt8, streamID: UInt32, timestamp: UInt32, payload: [UInt8]) {
        self.typeID = typeID
        self.streamID = streamID
        self.timestamp = timestamp
        self.payload = payload
    }
}
