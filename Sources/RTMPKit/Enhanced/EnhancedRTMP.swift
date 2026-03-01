// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Enhanced RTMP v2 negotiation and capability detection.
///
/// Enhanced RTMP extends the connect command with a `fourCcList` property
/// that signals supported codecs using FourCC values. The server responds
/// with its own supported list, and the intersection becomes available.
public struct EnhancedRTMP: Sendable {

    /// Whether Enhanced RTMP was negotiated with the server.
    public var isEnabled: Bool

    /// FourCC codecs supported by both client and server.
    public var negotiatedCodecs: [FourCC]

    /// Creates an Enhanced RTMP state.
    ///
    /// - Parameters:
    ///   - isEnabled: Whether enhanced RTMP is enabled (default false).
    ///   - negotiatedCodecs: Negotiated codecs (default empty).
    public init(isEnabled: Bool = false, negotiatedCodecs: [FourCC] = []) {
        self.isEnabled = isEnabled
        self.negotiatedCodecs = negotiatedCodecs
    }

    /// Default client codec list for the connect command.
    public static let defaultFourCcList: [FourCC] = [
        .hevc, .av1, .vp9, .opus, .flac, .ac3, .eac3
    ]

    /// Build the fourCcList AMF0 value for the connect command.
    ///
    /// Produces an AMF0 `strictArray` of string values, each being a
    /// 4-character FourCC string.
    ///
    /// - Parameter codecs: The FourCC codecs to include.
    /// - Returns: An AMF0 strictArray of string values.
    public static func fourCcListAMF0(codecs: [FourCC]) -> AMF0Value {
        .strictArray(codecs.map { .string($0.stringValue) })
    }

    /// Parse fourCcList from a server's _result response.
    ///
    /// Accepts both strictArray and ecmaArray of string values.
    ///
    /// - Parameter value: The AMF0 value containing the FourCC list.
    /// - Returns: An array of parsed FourCC values.
    public static func parseFourCcList(from value: AMF0Value) -> [FourCC] {
        let strings: [String]
        if let elements = value.arrayElements {
            strings = elements.compactMap { $0.stringValue }
        } else if let entries = value.ecmaArrayEntries {
            strings = entries.compactMap { $0.1.stringValue }
        } else {
            return []
        }
        return strings.compactMap { str in
            guard str.utf8.count == 4 else { return nil }
            return FourCC(stringValue: str)
        }
    }

    /// Check if a specific codec is available after negotiation.
    ///
    /// - Parameter fourCC: The FourCC codec to check.
    /// - Returns: `true` if the codec was negotiated.
    public func supports(_ fourCC: FourCC) -> Bool {
        negotiatedCodecs.contains(fourCC)
    }
}
