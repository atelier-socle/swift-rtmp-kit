// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Timed metadata that can be injected at any point during a live stream.
public enum TimedMetadata: Sendable {

    /// Plain text data — sent as `onTextData`.
    case text(String, timestamp: Double)

    /// Cue point — sent as `onCuePoint`.
    case cuePoint(CuePoint)

    /// Closed caption data — sent as `onCaptionInfo`.
    case caption(CaptionData)

    /// The RTMP Data Message name for this metadata type.
    public var messageName: String {
        switch self {
        case .text: return "onTextData"
        case .cuePoint: return "onCuePoint"
        case .caption: return "onCaptionInfo"
        }
    }

    /// The stream timestamp in milliseconds.
    public var timestamp: Double {
        switch self {
        case .text(_, let ts): return ts
        case .cuePoint(let cp): return cp.time
        case .caption(let cd): return cd.timestamp
        }
    }

    /// Encodes the payload as an AMF0 Value for wire transmission.
    ///
    /// - Returns: The AMF0 object representing this metadata payload.
    public func toAMF0Payload() -> AMF0Value {
        switch self {
        case .text(let text, _):
            return .object([
                ("text", .string(text)),
                ("language", .string("en"))
            ])
        case .cuePoint(let cp):
            return cp.toAMF0Object()
        case .caption(let cd):
            return cd.toAMF0Object()
        }
    }
}
