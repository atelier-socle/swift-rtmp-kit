// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Sends dynamic metadata updates during an active RTMP stream.
///
/// Owned by ``RTMPPublisher``. Not intended for direct instantiation by callers.
/// Encodes metadata as AMF0 Data Messages (type 18) and passes the encoded
/// bytes to a send closure provided at init time.
public actor MetadataUpdater {

    /// The closure that sends encoded RTMP Data Message bytes.
    private let sendClosure: @Sendable ([UInt8]) async throws -> Void

    /// Creates a MetadataUpdater.
    ///
    /// The sender closure is called with the encoded AMF0 payload bytes
    /// whenever metadata is sent.
    ///
    /// - Parameter send: Closure that transmits the encoded bytes.
    public init(send: @escaping @Sendable ([UInt8]) async throws -> Void) {
        self.sendClosure = send
    }

    // MARK: - Stream Metadata

    /// Send an `@setDataFrame`/`onMetaData` message with the provided metadata.
    ///
    /// Safe to call at any time during streaming — updates take effect immediately.
    ///
    /// - Parameter metadata: The stream metadata to send.
    public func updateStreamInfo(_ metadata: StreamMetadata) async throws {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            .string("@setDataFrame"),
            .string("onMetaData"),
            metadata.toAMF0()
        ])
        try await sendClosure(bytes)
    }

    // MARK: - Timed Metadata

    /// Inject timed metadata (onTextData, onCuePoint, onCaptionInfo).
    ///
    /// - Parameter timedMetadata: The timed metadata to send.
    public func send(_ timedMetadata: TimedMetadata) async throws {
        var encoder = AMF0Encoder()
        let bytes = encoder.encode([
            .string(timedMetadata.messageName),
            timedMetadata.toAMF0Payload()
        ])
        try await sendClosure(bytes)
    }

    // MARK: - Convenience

    /// Send an `onTextData` message with the given text.
    ///
    /// - Parameters:
    ///   - text: The text content.
    ///   - timestamp: Stream timestamp in milliseconds.
    public func sendText(_ text: String, timestamp: Double) async throws {
        try await send(.text(text, timestamp: timestamp))
    }

    /// Send an `onCuePoint` message.
    ///
    /// - Parameter cuePoint: The cue point to send.
    public func sendCuePoint(_ cuePoint: CuePoint) async throws {
        try await send(.cuePoint(cuePoint))
    }

    /// Send caption data as `onCaptionInfo`.
    ///
    /// - Parameter caption: The caption data to send.
    public func sendCaption(_ caption: CaptionData) async throws {
        try await send(.caption(caption))
    }
}
