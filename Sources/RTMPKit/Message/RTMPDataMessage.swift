// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// RTMP data messages (type 18 = AMF0 data).
///
/// Used primarily for sending stream metadata via @setDataFrame.
public enum RTMPDataMessage: Sendable, Equatable {

    /// Set metadata for the stream (@setDataFrame).
    case setDataFrame(metadata: StreamMetadata)

    /// Metadata notification from server.
    case onMetaData(metadata: AMF0Value)

    /// Message type ID (always 18 for AMF0 data).
    public static let typeID: UInt8 = 18

    /// Encode to AMF0 payload bytes.
    ///
    /// - Returns: The encoded AMF0 bytes for the message payload.
    public func encode() -> [UInt8] {
        var encoder = AMF0Encoder()
        switch self {
        case .setDataFrame(let metadata):
            return encoder.encode([
                .string("@setDataFrame"),
                .string("onMetaData"),
                metadata.toAMF0()
            ])
        case .onMetaData(let metadata):
            return encoder.encode([
                .string("onMetaData"),
                metadata
            ])
        }
    }

    /// Decode from AMF0 payload bytes.
    ///
    /// - Parameter bytes: The AMF0 payload bytes.
    /// - Returns: The decoded data message.
    /// - Throws: `MessageError` on invalid payload.
    public static func decode(from bytes: [UInt8]) throws -> RTMPDataMessage {
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        guard let first = values.first, let name = first.stringValue else {
            throw MessageError.invalidDataMessage("Missing data message name")
        }
        switch name {
        case "@setDataFrame":
            guard values.count >= 3 else {
                throw MessageError.invalidDataMessage("setDataFrame requires metadata")
            }
            let metadata = StreamMetadata.fromAMF0(values[2])
            return .setDataFrame(metadata: metadata)
        case "onMetaData":
            let metadata: AMF0Value = values.count > 1 ? values[1] : .null
            return .onMetaData(metadata: metadata)
        default:
            throw MessageError.invalidDataMessage("Unknown data message: \(name)")
        }
    }
}

/// Stream metadata for @setDataFrame.
///
/// Contains audio/video parameters that describe the stream being published.
/// All fields are optional — only non-nil fields are serialized.
public struct StreamMetadata: Sendable, Equatable {

    /// Video width in pixels.
    public var width: Double?

    /// Video height in pixels.
    public var height: Double?

    /// Video data rate in kbps.
    public var videoDataRate: Double?

    /// Video frame rate in fps.
    public var frameRate: Double?

    /// Video codec ID (7 = AVC/H.264, 12 = HEVC).
    public var videoCodecID: Double?

    /// Video bitrate in bps. Nil if unknown.
    public var videoBitrate: Int?

    /// Audio data rate in kbps.
    public var audioDataRate: Double?

    /// Audio sample rate in Hz.
    public var audioSampleRate: Double?

    /// Audio sample size in bits.
    public var audioSampleSize: Double?

    /// Whether audio is stereo.
    public var isStereo: Bool?

    /// Audio codec ID (10 = AAC).
    public var audioCodecID: Double?

    /// Number of audio channels (e.g. 1 = mono, 2 = stereo).
    public var audioChannels: Int?

    /// Audio bitrate in bps. Nil if unknown.
    public var audioBitrate: Int?

    /// Stream duration in seconds. 0 for live streams.
    public var duration: Double?

    /// Encoder name string.
    public var encoder: String?

    /// Additional arbitrary key-value pairs to include in the metadata object.
    public var customFields: [String: AMF0Value]

    /// Creates stream metadata with all fields nil.
    public init() {
        customFields = [:]
    }

    /// Convert to AMF0 ecmaArray value.
    ///
    /// Only non-nil properties are included in the array.
    ///
    /// - Returns: An AMF0 ecmaArray with the metadata key-value pairs.
    public func toAMF0() -> AMF0Value {
        var pairs: [(String, AMF0Value)] = []
        if let v = duration { pairs.append(("duration", .number(v))) }
        appendNumber("width", width, to: &pairs)
        appendNumber("height", height, to: &pairs)
        appendNumber("videodatarate", videoDataRate, to: &pairs)
        if let v = videoBitrate { pairs.append(("videoBitrate", .number(Double(v)))) }
        appendNumber("framerate", frameRate, to: &pairs)
        appendNumber("videocodecid", videoCodecID, to: &pairs)
        appendNumber("audiodatarate", audioDataRate, to: &pairs)
        if let v = audioBitrate { pairs.append(("audioBitrate", .number(Double(v)))) }
        appendNumber("audiosamplerate", audioSampleRate, to: &pairs)
        appendNumber("audiosamplesize", audioSampleSize, to: &pairs)
        if let v = isStereo { pairs.append(("stereo", .boolean(v))) }
        appendNumber("audiocodecid", audioCodecID, to: &pairs)
        if let v = audioChannels { pairs.append(("audioChannels", .number(Double(v)))) }
        if let v = encoder { pairs.append(("encoder", .string(v))) }
        for (key, value) in customFields {
            pairs.append((key, value))
        }
        return .ecmaArray(pairs)
    }

    /// Encodes this metadata as an AMF0 Object suitable for `@setDataFrame`/`onMetaData`.
    ///
    /// Alias for ``toAMF0()`` — returns the same ecmaArray encoding.
    public func toAMF0Object() -> AMF0Value {
        toAMF0()
    }

    private func appendNumber(
        _ key: String,
        _ value: Double?,
        to pairs: inout [(String, AMF0Value)]
    ) {
        if let v = value { pairs.append((key, .number(v))) }
    }

    /// Parse from AMF0 ecmaArray or object value.
    ///
    /// Missing properties are left nil.
    ///
    /// - Parameter value: An AMF0 ecmaArray or object value.
    /// - Returns: Parsed stream metadata.
    public static func fromAMF0(_ value: AMF0Value) -> StreamMetadata {
        let pairs: [(String, AMF0Value)]
        if let p = value.ecmaArrayEntries {
            pairs = p
        } else if let p = value.objectProperties {
            pairs = p
        } else {
            return StreamMetadata()
        }
        let dict = Dictionary(pairs, uniquingKeysWith: { _, last in last })
        var meta = StreamMetadata()
        meta.width = dict["width"]?.numberValue
        meta.height = dict["height"]?.numberValue
        meta.videoDataRate = dict["videodatarate"]?.numberValue
        meta.frameRate = dict["framerate"]?.numberValue
        meta.videoCodecID = dict["videocodecid"]?.numberValue
        meta.videoBitrate = dict["videoBitrate"]?.numberValue.map { Int($0) }
        meta.audioDataRate = dict["audiodatarate"]?.numberValue
        meta.audioSampleRate = dict["audiosamplerate"]?.numberValue
        meta.audioSampleSize = dict["audiosamplesize"]?.numberValue
        meta.isStereo = dict["stereo"]?.booleanValue
        meta.audioCodecID = dict["audiocodecid"]?.numberValue
        meta.audioChannels = dict["audioChannels"]?.numberValue.map { Int($0) }
        meta.audioBitrate = dict["audioBitrate"]?.numberValue.map { Int($0) }
        meta.duration = dict["duration"]?.numberValue
        meta.encoder = dict["encoder"]?.stringValue
        return meta
    }
}
