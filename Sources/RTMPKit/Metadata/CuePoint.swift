// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// An RTMP cue point — marks a specific moment in a stream.
///
/// Sent as an `onCuePoint` RTMP Data Message.
public struct CuePoint: Sendable, Equatable {

    /// The type of cue point.
    public enum CuePointType: String, Sendable, Equatable, CaseIterable {
        /// Navigation cue — marks a chapter or scene boundary.
        case navigation
        /// Event cue — marks an ad break, sponsored segment, or custom event.
        case event
    }

    /// Cue point name (arbitrary string identifier).
    public let name: String

    /// Stream time in milliseconds at which this cue point occurs.
    public let time: Double

    /// Type of cue point.
    public let type: CuePointType

    /// Optional arbitrary parameters for this cue point.
    public let parameters: [String: AMF0Value]

    /// Creates a cue point.
    ///
    /// - Parameters:
    ///   - name: Name of the cue point.
    ///   - time: Stream time in milliseconds.
    ///   - type: Cue point type (default: `.navigation`).
    ///   - parameters: Additional key-value parameters (default: empty).
    public init(
        name: String,
        time: Double,
        type: CuePointType = .navigation,
        parameters: [String: AMF0Value] = [:]
    ) {
        self.name = name
        self.time = time
        self.type = type
        self.parameters = parameters
    }

    /// Encodes this cue point as an AMF0 Object for wire transmission.
    ///
    /// - Returns: An AMF0 object containing name, time, type, and parameters.
    public func toAMF0Object() -> AMF0Value {
        var pairs: [(String, AMF0Value)] = [
            ("name", .string(name)),
            ("time", .number(time)),
            ("type", .string(type.rawValue))
        ]
        for (key, value) in parameters {
            pairs.append((key, value))
        }
        return .object(pairs)
    }
}
