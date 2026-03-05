// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Raw Payload Sending

extension RTMPPublisher {

    /// Send a raw video tag payload (already formatted as FLV video tag body).
    ///
    /// Use this when the payload is already in wire format (e.g., from an FLV file).
    /// No additional FLV wrapping (AVC NALU or enhanced) is applied.
    /// ABR frame dropping is still applied for non-keyframes.
    ///
    /// - Parameters:
    ///   - payload: The complete FLV video tag body bytes.
    ///   - timestamp: The presentation timestamp in milliseconds.
    ///   - isKeyframe: Whether this frame is a keyframe (I-frame).
    public func sendVideoPayload(
        _ payload: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) async throws {
        guard session.state == .publishing else {
            throw RTMPError.notPublishing
        }

        // ABR frame dropping evaluation
        if let abrMon = abrMonitor, let config = currentConfiguration {
            if let snapshot = await abrMon.currentSnapshot {
                let congestion = computeCongestionLevel(
                    from: snapshot, configuration: config
                )
                let priority: FrameDroppingStrategy.FramePriority =
                    isKeyframe ? .iFrame : .pFrame
                if config.frameDroppingStrategy.shouldDrop(
                    priority: priority,
                    consecutiveDropCount: consecutiveDropCount,
                    congestionLevel: congestion
                ) {
                    consecutiveDropCount += 1
                    await abrMon.recordDroppedFrame()
                    monitor.recordDroppedFrame()
                    await recordFrameDropForQuality()
                    return
                }
            }
            consecutiveDropCount = 0
            await abrMon.recordSentFrame()
        }

        let message = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: connection.streamID ?? 1,
            timestamp: timestamp, payload: payload
        )
        try await sendRTMPMessage(message, chunkStreamID: .video)
        monitor.recordVideoFrameSent()
        monitor.recordBytesSent(
            UInt64(payload.count), at: monotonicNow()
        )

        if let abrMon = abrMonitor {
            await abrMon.recordBytesSent(payload.count, pendingBytes: 0)
        }
        await recordBytesForQuality(payload.count)
        await recordSentFrameForQuality()
        await recordVideoFrame(
            payload, timestamp: timestamp, isKeyframe: isKeyframe
        )
    }

    /// Send a raw video config payload (already formatted as FLV sequence header).
    ///
    /// Use this when the payload is already in wire format (e.g., from an FLV file).
    /// No additional FLV wrapping is applied.
    ///
    /// - Parameter payload: The complete FLV video sequence header bytes.
    public func sendVideoConfigPayload(_ payload: [UInt8]) async throws {
        guard session.state == .publishing else {
            throw RTMPError.notPublishing
        }
        let message = RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: connection.streamID ?? 1,
            timestamp: 0, payload: payload
        )
        try await sendRTMPMessage(message, chunkStreamID: .video)
    }

    /// Send a raw audio tag payload (already formatted as FLV audio tag body).
    ///
    /// Use this when the payload is already in wire format (e.g., from an FLV file).
    /// No additional FLV wrapping is applied.
    ///
    /// - Parameters:
    ///   - payload: The complete FLV audio tag body bytes.
    ///   - timestamp: The presentation timestamp in milliseconds.
    public func sendAudioPayload(
        _ payload: [UInt8], timestamp: UInt32
    ) async throws {
        guard session.state == .publishing else {
            throw RTMPError.notPublishing
        }
        let message = RTMPMessage(
            typeID: RTMPMessage.typeIDAudio,
            streamID: connection.streamID ?? 1,
            timestamp: timestamp, payload: payload
        )
        try await sendRTMPMessage(message, chunkStreamID: .audio)
        monitor.recordAudioFrameSent()
        monitor.recordBytesSent(
            UInt64(payload.count), at: monotonicNow()
        )

        if let abrMon = abrMonitor {
            await abrMon.recordBytesSent(payload.count, pendingBytes: 0)
        }
        await recordBytesForQuality(payload.count)
        await recordAudioFrame(payload, timestamp: timestamp)
    }

    /// Send a raw audio config payload (already formatted as FLV audio sequence header).
    ///
    /// Use this when the payload is already in wire format (e.g., from an FLV file).
    /// No additional FLV wrapping is applied.
    ///
    /// - Parameter payload: The complete FLV audio sequence header bytes.
    public func sendAudioConfigPayload(_ payload: [UInt8]) async throws {
        guard session.state == .publishing else {
            throw RTMPError.notPublishing
        }
        let message = RTMPMessage(
            typeID: RTMPMessage.typeIDAudio,
            streamID: connection.streamID ?? 1,
            timestamp: 0, payload: payload
        )
        try await sendRTMPMessage(message, chunkStreamID: .audio)
    }
}
