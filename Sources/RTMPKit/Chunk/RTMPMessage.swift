// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A complete RTMP message reassembled from chunks.
///
/// This is the unit of communication in the RTMP protocol. Messages are
/// split into chunks for transport and reassembled by the ``ChunkAssembler``.
/// The message type ID determines how the payload should be interpreted
/// (protocol control, command, audio, video, etc.).
public struct RTMPMessage: Sendable, Equatable {

    // MARK: - Well-Known Type IDs

    /// Set Chunk Size (type 1).
    public static let typeIDSetChunkSize: UInt8 = 1
    /// Abort Message (type 2).
    public static let typeIDAbort: UInt8 = 2
    /// Acknowledgement (type 3).
    public static let typeIDAcknowledgement: UInt8 = 3
    /// User Control Event (type 4).
    public static let typeIDUserControl: UInt8 = 4
    /// Window Acknowledgement Size (type 5).
    public static let typeIDWindowAckSize: UInt8 = 5
    /// Set Peer Bandwidth (type 6).
    public static let typeIDSetPeerBandwidth: UInt8 = 6
    /// Audio data (type 8).
    public static let typeIDAudio: UInt8 = 8
    /// Video data (type 9).
    public static let typeIDVideo: UInt8 = 9
    /// AMF0 Data Message (type 18).
    public static let typeIDDataAMF0: UInt8 = 18
    /// AMF0 Command Message (type 20).
    public static let typeIDCommandAMF0: UInt8 = 20

    // MARK: - Properties

    /// RTMP message type ID.
    public var typeID: UInt8

    /// Message stream ID.
    public var streamID: UInt32

    /// Timestamp in milliseconds.
    public var timestamp: UInt32

    /// Message payload bytes.
    public var payload: [UInt8]

    // MARK: - Initializers

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

    /// Creates an RTMP message from an AMF0 command.
    ///
    /// - Parameters:
    ///   - command: The command to encode as payload.
    ///   - streamID: The message stream ID (default 0).
    ///   - timestamp: The timestamp in milliseconds (default 0).
    public init(command: RTMPCommand, streamID: UInt32 = 0, timestamp: UInt32 = 0) {
        self.typeID = Self.typeIDCommandAMF0
        self.streamID = streamID
        self.timestamp = timestamp
        self.payload = command.encode()
    }

    /// Creates an RTMP message from a protocol control message.
    ///
    /// Control messages always use message stream ID 0.
    ///
    /// - Parameters:
    ///   - controlMessage: The control message to encode as payload.
    ///   - timestamp: The timestamp in milliseconds (default 0).
    public init(controlMessage: RTMPControlMessage, timestamp: UInt32 = 0) {
        self.typeID = controlMessage.typeID
        self.streamID = 0
        self.timestamp = timestamp
        self.payload = controlMessage.encode()
    }

    /// Creates an RTMP message from a user control event.
    ///
    /// User control events always use message stream ID 0.
    ///
    /// - Parameters:
    ///   - userControlEvent: The user control event to encode as payload.
    ///   - timestamp: The timestamp in milliseconds (default 0).
    public init(userControlEvent: RTMPUserControlEvent, timestamp: UInt32 = 0) {
        self.typeID = Self.typeIDUserControl
        self.streamID = 0
        self.timestamp = timestamp
        self.payload = userControlEvent.encode()
    }

    /// Creates an RTMP message from an AMF0 data message.
    ///
    /// - Parameters:
    ///   - dataMessage: The data message to encode as payload.
    ///   - streamID: The message stream ID.
    ///   - timestamp: The timestamp in milliseconds (default 0).
    public init(dataMessage: RTMPDataMessage, streamID: UInt32, timestamp: UInt32 = 0) {
        self.typeID = Self.typeIDDataAMF0
        self.streamID = streamID
        self.timestamp = timestamp
        self.payload = dataMessage.encode()
    }
}
