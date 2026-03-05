// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Stream Management

extension RTMPServer {

    // MARK: - Relay

    /// Attach a relay to a specific stream.
    ///
    /// All video and audio frames from the named stream will be
    /// forwarded to the relay destinations.
    ///
    /// - Parameters:
    ///   - relay: The relay to attach.
    ///   - streamName: Stream name to relay (e.g. "live/myStream").
    public func attachRelay(
        _ relay: RTMPStreamRelay, toStream streamName: String
    ) {
        relays[streamName] = relay
    }

    /// Detach a relay from a stream.
    ///
    /// Stops the relay and removes it from the server.
    ///
    /// - Parameter streamName: The stream name to detach from.
    public func detachRelay(fromStream streamName: String) async {
        guard let relay = relays.removeValue(forKey: streamName) else {
            return
        }
        await relay.stop()
    }

    // MARK: - DVR

    /// Attach a DVR recorder to a specific stream.
    ///
    /// All video and audio frames from the named stream will be
    /// recorded by the DVR.
    ///
    /// - Parameters:
    ///   - dvr: The DVR recorder to attach.
    ///   - streamName: Stream name to record.
    public func attachDVR(
        _ dvr: RTMPStreamDVR, toStream streamName: String
    ) {
        dvrs[streamName] = dvr
    }

    /// Detach DVR from a stream and return the final segment.
    ///
    /// Stops the DVR and removes it from the server.
    ///
    /// - Parameter streamName: The stream name to detach from.
    /// - Returns: The final recording segment, or nil if nothing was written.
    @discardableResult
    public func detachDVR(
        fromStream streamName: String
    ) async throws -> RecordingSegment? {
        guard let dvr = dvrs.removeValue(forKey: streamName) else {
            return nil
        }
        return try await dvr.stop()
    }

    // MARK: - Stream Info

    /// Returns the session currently publishing the named stream, if any.
    ///
    /// - Parameter streamName: The stream name to look up.
    /// - Returns: The matching session, or nil.
    public func session(
        forStream streamName: String
    ) async -> RTMPServerSession? {
        for (_, session) in sessions {
            let name = await session.streamName
            if name == streamName {
                return session
            }
        }
        return nil
    }

    /// All stream names currently being published.
    public var activeStreamNames: [String] {
        get async {
            var names: [String] = []
            for (_, session) in sessions {
                if let name = await session.streamName {
                    names.append(name)
                }
            }
            return names
        }
    }
}
