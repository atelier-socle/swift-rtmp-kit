// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Known Twitch ingest server locations (PoPs).
///
/// Use ``auto`` for automatic server selection via `live.twitch.tv`.
/// Specify a regional server for lower latency to a specific PoP.
///
/// ## Usage
/// ```swift
/// let config = RTMPConfiguration.twitch(
///     streamKey: "live_xxx",
///     ingestServer: .usEast
/// )
/// ```
public enum TwitchIngestServer: String, Sendable, CaseIterable, Equatable {

    /// Automatic — Twitch selects the best server.
    case auto = "live.twitch.tv"

    /// US East (Ashburn, VA).
    case usEast = "iad05.contribute.live-video.net"

    /// US West (Seattle, WA).
    case usWest = "sea02.contribute.live-video.net"

    /// Europe (Amsterdam, NL).
    case europe = "ams03.contribute.live-video.net"

    /// Asia (Tokyo, JP).
    case asia = "tyo05.contribute.live-video.net"

    /// South America (São Paulo, BR).
    case southAmerica = "gru01.contribute.live-video.net"

    /// Australia (Sydney, AU).
    case australia = "syd01.contribute.live-video.net"

    /// The hostname for this ingest server.
    public var hostname: String { rawValue }
}
