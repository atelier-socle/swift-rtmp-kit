// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Dynamic Metadata

extension RTMPPublisher {

    /// Send a stream metadata update mid-stream.
    ///
    /// Encodes as `@setDataFrame`/`onMetaData` RTMP Data Message.
    /// Safe to call at any time while connected.
    ///
    /// - Parameter metadata: The stream metadata to send.
    public func updateStreamInfo(_ metadata: StreamMetadata) async throws {
        guard let updater = metadataUpdater else {
            throw RTMPError.notPublishing
        }
        try await updater.updateStreamInfo(metadata)
    }

    /// Inject timed metadata (onTextData, onCuePoint, onCaptionInfo).
    ///
    /// - Parameter timedMetadata: The timed metadata to send.
    public func send(_ timedMetadata: TimedMetadata) async throws {
        guard let updater = metadataUpdater else {
            throw RTMPError.notPublishing
        }
        try await updater.send(timedMetadata)
    }

    /// Convenience: send `onTextData`.
    ///
    /// - Parameters:
    ///   - text: The text content.
    ///   - timestamp: Stream timestamp in milliseconds.
    public func sendText(_ text: String, timestamp: Double) async throws {
        guard let updater = metadataUpdater else {
            throw RTMPError.notPublishing
        }
        try await updater.sendText(text, timestamp: timestamp)
    }

    /// Convenience: send `onCuePoint`.
    ///
    /// - Parameter cuePoint: The cue point to send.
    public func sendCuePoint(_ cuePoint: CuePoint) async throws {
        guard let updater = metadataUpdater else {
            throw RTMPError.notPublishing
        }
        try await updater.sendCuePoint(cuePoint)
    }

    /// Convenience: send `onCaptionInfo`.
    ///
    /// - Parameter caption: The caption data to send.
    public func sendCaption(_ caption: CaptionData) async throws {
        guard let updater = metadataUpdater else {
            throw RTMPError.notPublishing
        }
        try await updater.sendCaption(caption)
    }

    // MARK: - Internal

    /// Creates and stores the MetadataUpdater with a send closure
    /// that wraps AMF0 payloads into RTMP Data Messages.
    internal func setupMetadataUpdater() {
        metadataUpdater = MetadataUpdater { [weak self] bytes in
            guard let self else { throw RTMPError.notPublishing }
            try await self.sendDataMessagePayload(bytes)
        }
    }

    /// Sends raw AMF0 payload bytes as an RTMP Data Message (type 18).
    ///
    /// Use this to forward FLV script tags (e.g. `@setDataFrame`/`onMetaData`)
    /// verbatim from an FLV file reader.
    ///
    /// - Parameter payload: Raw AMF0-encoded payload bytes.
    public func sendDataMessagePayload(_ payload: [UInt8]) async throws {
        guard
            session.state == .publishing
                || session.state == .connected
        else {
            throw RTMPError.notPublishing
        }
        let message = RTMPMessage(
            typeID: RTMPDataMessage.typeID,
            streamID: connection.streamID ?? 1,
            timestamp: 0,
            payload: payload
        )
        try await sendRTMPMessage(message, chunkStreamID: .command)
    }
}
