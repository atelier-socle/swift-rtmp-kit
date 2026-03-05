// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Raw Payload Sending

extension MultiPublisher {

    /// Send a raw video payload to all active destinations.
    ///
    /// The payload is sent as-is without additional FLV wrapping.
    /// Destinations not in ``DestinationState/streaming`` state silently skip this frame.
    ///
    /// - Parameters:
    ///   - payload: The complete FLV video tag body bytes.
    ///   - timestamp: The presentation timestamp.
    ///   - isKeyframe: Whether this frame is a keyframe (I-frame).
    public func sendVideoPayload(
        _ payload: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for (id, handle) in handles {
                guard destinationStates[id] == .streaming else { continue }
                group.addTask {
                    try? await handle.publisher.sendVideoPayload(
                        payload, timestamp: timestamp, isKeyframe: isKeyframe
                    )
                }
            }
        }
        await updateAndEmitStatistics()
    }

    /// Send a raw video config payload to all active destinations.
    ///
    /// The payload is sent as-is without additional FLV wrapping.
    /// Destinations not in ``DestinationState/streaming`` state silently skip.
    ///
    /// - Parameter payload: The complete FLV video sequence header bytes.
    public func sendVideoConfigPayload(_ payload: [UInt8]) async {
        await withTaskGroup(of: Void.self) { group in
            for (id, handle) in handles {
                guard destinationStates[id] == .streaming else { continue }
                group.addTask {
                    try? await handle.publisher.sendVideoConfigPayload(payload)
                }
            }
        }
    }

    /// Send a raw audio payload to all active destinations.
    ///
    /// The payload is sent as-is without additional FLV wrapping.
    /// Destinations not in ``DestinationState/streaming`` state silently skip this frame.
    ///
    /// - Parameters:
    ///   - payload: The complete FLV audio tag body bytes.
    ///   - timestamp: The presentation timestamp.
    public func sendAudioPayload(
        _ payload: [UInt8], timestamp: UInt32
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for (id, handle) in handles {
                guard destinationStates[id] == .streaming else { continue }
                group.addTask {
                    try? await handle.publisher.sendAudioPayload(
                        payload, timestamp: timestamp
                    )
                }
            }
        }
        await updateAndEmitStatistics()
    }

    /// Send a raw audio config payload to all active destinations.
    ///
    /// The payload is sent as-is without additional FLV wrapping.
    /// Destinations not in ``DestinationState/streaming`` state silently skip.
    ///
    /// - Parameter payload: The complete FLV audio sequence header bytes.
    public func sendAudioConfigPayload(_ payload: [UInt8]) async {
        await withTaskGroup(of: Void.self) { group in
            for (id, handle) in handles {
                guard destinationStates[id] == .streaming else { continue }
                group.addTask {
                    try? await handle.publisher.sendAudioConfigPayload(payload)
                }
            }
        }
    }
}
