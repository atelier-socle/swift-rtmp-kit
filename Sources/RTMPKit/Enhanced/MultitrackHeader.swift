// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Multitrack header for Enhanced RTMP v2 (future implementation).
///
/// Multitrack allows multiple concurrent audio or video streams
/// within a single RTMP connection. Deferred to future version.
public enum MultitrackType: UInt8, Sendable {
    /// Single track.
    case oneTrack = 0
    /// Multiple tracks, same codec.
    case manyTracks = 1
    /// Multiple tracks, different codecs.
    case manyTracksManyCodecs = 2
}
