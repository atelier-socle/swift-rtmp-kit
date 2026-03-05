// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A single RTMP publisher session connected to the server.
///
/// Manages the full session lifecycle: handshake, connect, publish,
/// media reception, and disconnect. Uses actor isolation for thread safety.
public actor RTMPServerSession: Identifiable {

    // MARK: - Identity

    /// Unique session identifier.
    public let id: UUID

    /// The stream key/name this session is publishing to.
    public private(set) var streamName: String?

    /// The application name from the connect command (e.g. "live").
    public private(set) var appName: String?

    /// Remote address of the publisher.
    public let remoteAddress: String

    // MARK: - State

    /// Session lifecycle states.
    public enum State: Sendable, Equatable {
        /// Performing RTMP handshake.
        case handshaking
        /// Connect command received, not yet publishing.
        case connected
        /// Publish command received, stream active.
        case publishing
        /// Session stopped gracefully.
        case stopped
        /// Session failed with a reason.
        case failed(String)
    }

    /// Current session state.
    public private(set) var state: State

    // MARK: - Statistics

    /// Total bytes received from this publisher.
    public private(set) var bytesReceived: Int

    /// Total video frames received.
    public private(set) var videoFramesReceived: Int

    /// Total audio frames received.
    public private(set) var audioFramesReceived: Int

    /// Wall-clock time when this session connected.
    public let connectedAt: Double

    // MARK: - Internal

    let transport: any RTMPTransportProtocol
    var disassembler: ChunkDisassembler
    var assembler: ChunkAssembler
    private var assignedStreamID: UInt32 = 1

    /// Creates a new server session.
    ///
    /// - Parameters:
    ///   - id: Unique session identifier.
    ///   - transport: The transport for this connection.
    ///   - remoteAddress: Remote address string.
    ///   - connectedAt: Wall-clock timestamp of connection.
    init(
        id: UUID = UUID(),
        transport: any RTMPTransportProtocol,
        remoteAddress: String = "unknown",
        connectedAt: Double = 0
    ) {
        self.id = id
        self.transport = transport
        self.remoteAddress = remoteAddress
        self.connectedAt = connectedAt
        self.state = .handshaking
        self.bytesReceived = 0
        self.videoFramesReceived = 0
        self.audioFramesReceived = 0
        self.disassembler = ChunkDisassembler(chunkSize: 4096)
        self.assembler = ChunkAssembler()
    }

    // MARK: - Lifecycle

    /// Gracefully close this session.
    public func close() async {
        state = .stopped
        try? await transport.close()
    }

    // MARK: - State Transitions

    /// Transition to connected state after handshake.
    func transitionToConnected(appName: String?) {
        self.appName = appName
        state = .connected
    }

    /// Transition to publishing state.
    func transitionToPublishing(streamName: String) {
        self.streamName = streamName
        state = .publishing
    }

    /// Transition to failed state.
    func transitionToFailed(_ reason: String) {
        state = .failed(reason)
    }

    // MARK: - Statistics Recording

    /// Record bytes received.
    func recordBytesReceived(_ count: Int) {
        bytesReceived += count
    }

    /// Record a video frame received.
    func recordVideoFrame() {
        videoFramesReceived += 1
    }

    /// Record an audio frame received.
    func recordAudioFrame() {
        audioFramesReceived += 1
    }

    // MARK: - Message Sending

    /// Send an RTMP message to the publisher client.
    func sendMessage(
        _ message: RTMPMessage, chunkStreamID: ChunkStreamID
    ) async throws {
        let bytes = disassembler.disassemble(
            message: message, chunkStreamID: chunkStreamID
        )
        try await transport.send(bytes)
    }

    /// Send a command message to the client.
    func sendCommand(
        _ command: RTMPCommand, chunkStreamID: ChunkStreamID
    ) async throws {
        let message = RTMPMessage(command: command)
        try await sendMessage(message, chunkStreamID: chunkStreamID)
    }

    // MARK: - RTMP Command Responses

    /// Send connect success response.
    func sendConnectResult(transactionID: Double) async throws {
        let props: AMF0Value = .object([
            ("fmsVer", .string("FMS/3,0,1,123")),
            ("capabilities", .number(31.0))
        ])
        let info: AMF0Value = .object([
            ("level", .string("status")),
            ("code", .string("NetConnection.Connect.Success")),
            ("description", .string("Connection succeeded.")),
            ("objectEncoding", .number(0.0))
        ])
        try await sendCommand(
            .result(
                transactionID: transactionID,
                properties: props,
                information: info
            ),
            chunkStreamID: .command
        )
    }

    /// Send a generic _result acknowledgement.
    func sendResultAck(transactionID: Double) async throws {
        try await sendCommand(
            .result(
                transactionID: transactionID,
                properties: nil,
                information: nil
            ),
            chunkStreamID: .command
        )
    }

    /// Send createStream result with stream ID.
    func sendCreateStreamResult(
        transactionID: Double, streamID: Double
    ) async throws {
        try await sendCommand(
            .result(
                transactionID: transactionID,
                properties: nil,
                information: .number(streamID)
            ),
            chunkStreamID: .command
        )
    }

    /// Send publish start status.
    func sendPublishStart(streamName: String) async throws {
        let info: AMF0Value = .object([
            ("level", .string("status")),
            ("code", .string("NetStream.Publish.Start")),
            ("description", .string("\(streamName) is now published.")),
            ("details", .string(streamName))
        ])
        try await sendCommand(
            .onStatus(information: info),
            chunkStreamID: .command
        )
    }

    /// Send publish rejected (bad name) status.
    func sendPublishBadName(streamName: String) async throws {
        let info: AMF0Value = .object([
            ("level", .string("error")),
            ("code", .string("NetStream.Publish.BadName")),
            ("description", .string("\(streamName) is already publishing."))
        ])
        try await sendCommand(
            .onStatus(information: info),
            chunkStreamID: .command
        )
    }

    /// Send onFCPublish notification.
    func sendOnFCPublish(streamName: String) async throws {
        let info: AMF0Value = .object([
            ("code", .string("NetStream.Publish.Start")),
            ("description", .string("\(streamName)"))
        ])
        try await sendCommand(
            .onStatus(information: info),
            chunkStreamID: .command
        )
    }

    /// Send onFCUnpublish notification.
    func sendOnFCUnpublish(streamName: String) async throws {
        let info: AMF0Value = .object([
            ("code", .string("NetStream.Unpublish.Success")),
            ("description", .string("\(streamName)"))
        ])
        try await sendCommand(
            .onStatus(information: info),
            chunkStreamID: .command
        )
    }

    /// Update the send chunk size.
    func setChunkSize(_ size: Int) {
        disassembler.setChunkSize(UInt32(size))
    }

    /// Update the receive chunk size.
    func setReceiveChunkSize(_ size: UInt32) {
        assembler.setChunkSize(size)
    }
}
