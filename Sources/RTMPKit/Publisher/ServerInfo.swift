// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Server information from the RTMP connect `_result` response.
///
/// Contains the server software version, capabilities, and
/// Enhanced RTMP negotiation results.
public struct ServerInfo: Sendable, Equatable {

    /// Server software version (from `fmsVer` property).
    public var version: String?

    /// Server capabilities bitmask.
    public var capabilities: Double?

    /// AMF object encoding version.
    public var objectEncoding: Double?

    /// Whether Enhanced RTMP was negotiated.
    public var enhancedRTMP: Bool

    /// Codecs negotiated via Enhanced RTMP `fourCcList`.
    public var negotiatedCodecs: [FourCC]

    /// Creates empty server info.
    public init() {
        self.version = nil
        self.capabilities = nil
        self.objectEncoding = nil
        self.enhancedRTMP = false
        self.negotiatedCodecs = []
    }
}
