// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// RTMP command messages (type 20 = AMF0 command).
///
/// Commands are serialized as sequences of AMF0 values and carried
/// in RTMP messages with type ID 20.
public enum RTMPCommand: Sendable, Equatable {

    /// Connect to server application.
    case connect(transactionID: Double, properties: ConnectProperties)

    /// Server response to a command.
    case result(transactionID: Double, properties: AMF0Value?, information: AMF0Value?)

    /// Server error response.
    case error(transactionID: Double, properties: AMF0Value?, information: AMF0Value?)

    /// Create a new stream.
    case createStream(transactionID: Double)

    /// Start publishing.
    case publish(transactionID: Double, streamName: String, publishType: String)

    /// Release a stream (Twitch/YouTube pre-publish).
    case releaseStream(transactionID: Double, streamName: String)

    /// FCPublish (Flash Communication publish — Twitch/YouTube).
    case fcPublish(transactionID: Double, streamName: String)

    /// FCUnpublish.
    case fcUnpublish(transactionID: Double, streamName: String)

    /// Delete a stream.
    case deleteStream(transactionID: Double, streamID: Double)

    /// Server status notification.
    case onStatus(information: AMF0Value)

    /// Message type ID (always 20 for AMF0 commands).
    public static let typeID: UInt8 = 20

    /// Encode to AMF0 payload bytes.
    ///
    /// - Returns: The encoded AMF0 bytes for the message payload.
    public func encode() -> [UInt8] {
        var encoder = AMF0Encoder()
        return encoder.encode(toAMF0Values())
    }

    /// Decode from AMF0 payload bytes.
    ///
    /// - Parameter bytes: The AMF0 payload bytes.
    /// - Returns: The decoded command.
    /// - Throws: `MessageError` on unknown command or invalid payload.
    public static func decode(from bytes: [UInt8]) throws -> RTMPCommand {
        var decoder = AMF0Decoder()
        let values = try decoder.decodeAll(from: bytes)
        guard let first = values.first, let name = first.stringValue else {
            throw MessageError.invalidCommandPayload("Missing command name")
        }
        guard values.count >= 2, let txnID = values[1].numberValue else {
            throw MessageError.invalidCommandPayload("Missing transaction ID")
        }
        return try decodeByName(name, txnID: txnID, values: values)
    }
}

// MARK: - AMF0 Encoding

extension RTMPCommand {

    func toAMF0Values() -> [AMF0Value] {
        switch self {
        case .connect(let txnID, let props):
            return [.string("connect"), .number(txnID), props.toAMF0()]
        case .result(let txnID, let props, let info):
            return [
                .string("_result"), .number(txnID),
                props ?? .null, info ?? .null
            ]
        case .error(let txnID, let props, let info):
            return [
                .string("_error"), .number(txnID),
                props ?? .null, info ?? .null
            ]
        case .createStream(let txnID):
            return [.string("createStream"), .number(txnID), .null]
        case .publish(let txnID, let name, let type):
            return [.string("publish"), .number(txnID), .null, .string(name), .string(type)]
        case .releaseStream(let txnID, let name):
            return [.string("releaseStream"), .number(txnID), .null, .string(name)]
        case .fcPublish(let txnID, let name):
            return [.string("FCPublish"), .number(txnID), .null, .string(name)]
        case .fcUnpublish(let txnID, let name):
            return [.string("FCUnpublish"), .number(txnID), .null, .string(name)]
        case .deleteStream(let txnID, let streamID):
            return [.string("deleteStream"), .number(txnID), .null, .number(streamID)]
        case .onStatus(let info):
            return [.string("onStatus"), .number(0), .null, info]
        }
    }
}

// MARK: - AMF0 Decoding

extension RTMPCommand {

    private static func decodeByName(
        _ name: String,
        txnID: Double,
        values: [AMF0Value]
    ) throws -> RTMPCommand {
        switch name {
        case "connect":
            return try decodeConnect(txnID: txnID, values: values)
        case "_result":
            return decodeResult(txnID: txnID, values: values)
        case "_error":
            return decodeError(txnID: txnID, values: values)
        case "createStream":
            return .createStream(transactionID: txnID)
        case "publish":
            return try decodePublish(txnID: txnID, values: values)
        case "releaseStream", "FCPublish", "FCUnpublish":
            return try decodeStreamName(name, txnID: txnID, values: values)
        case "deleteStream":
            return try decodeDeleteStream(txnID: txnID, values: values)
        case "onStatus":
            return decodeOnStatus(values: values)
        default:
            throw MessageError.unknownCommand(name)
        }
    }

    private static func decodeConnect(
        txnID: Double,
        values: [AMF0Value]
    ) throws -> RTMPCommand {
        guard values.count >= 3 else {
            throw MessageError.invalidCommandPayload("connect requires properties object")
        }
        let props = ConnectProperties.fromAMF0(values[2])
        return .connect(transactionID: txnID, properties: props)
    }

    private static func decodeResult(txnID: Double, values: [AMF0Value]) -> RTMPCommand {
        let props = values.count > 2 ? nullToNil(values[2]) : nil
        let info = values.count > 3 ? nullToNil(values[3]) : nil
        return .result(transactionID: txnID, properties: props, information: info)
    }

    private static func decodeError(txnID: Double, values: [AMF0Value]) -> RTMPCommand {
        let props = values.count > 2 ? nullToNil(values[2]) : nil
        let info = values.count > 3 ? nullToNil(values[3]) : nil
        return .error(transactionID: txnID, properties: props, information: info)
    }

    private static func decodePublish(
        txnID: Double,
        values: [AMF0Value]
    ) throws -> RTMPCommand {
        guard values.count >= 4, let name = values[3].stringValue else {
            throw MessageError.invalidCommandPayload("publish requires stream name")
        }
        let publishType = values.count > 4 ? (values[4].stringValue ?? "live") : "live"
        return .publish(transactionID: txnID, streamName: name, publishType: publishType)
    }

    private static func decodeStreamName(
        _ commandName: String,
        txnID: Double,
        values: [AMF0Value]
    ) throws -> RTMPCommand {
        guard values.count >= 4, let name = values[3].stringValue else {
            throw MessageError.invalidCommandPayload("\(commandName) requires stream name")
        }
        switch commandName {
        case "releaseStream": return .releaseStream(transactionID: txnID, streamName: name)
        case "FCPublish": return .fcPublish(transactionID: txnID, streamName: name)
        default: return .fcUnpublish(transactionID: txnID, streamName: name)
        }
    }

    private static func decodeDeleteStream(
        txnID: Double,
        values: [AMF0Value]
    ) throws -> RTMPCommand {
        guard values.count >= 4, let streamID = values[3].numberValue else {
            throw MessageError.invalidCommandPayload("deleteStream requires stream ID")
        }
        return .deleteStream(transactionID: txnID, streamID: streamID)
    }

    private static func decodeOnStatus(values: [AMF0Value]) -> RTMPCommand {
        let info: AMF0Value = values.count > 3 ? values[3] : .null
        return .onStatus(information: info)
    }

    private static func nullToNil(_ value: AMF0Value) -> AMF0Value? {
        if case .null = value { return nil }
        return value
    }
}

/// Properties for the RTMP connect command.
///
/// Serialized as an AMF0 object with properties in a specific order
/// required by most RTMP servers.
public struct ConnectProperties: Sendable, Equatable {

    /// Application name on the server.
    public var app: String

    /// Flash player version string.
    public var flashVer: String

    /// URL of the server application.
    public var tcUrl: String

    /// Connection type.
    public var type: String

    /// Whether proxy is used.
    public var fpad: Bool

    /// Audio/video capabilities.
    public var capabilities: Double

    /// Supported audio codecs bitmask.
    public var audioCodecs: Double

    /// Supported video codecs bitmask.
    public var videoCodecs: Double

    /// Video function support.
    public var videoFunction: Double

    /// AMF encoding version (0 = AMF0).
    public var objectEncoding: Double

    /// Additional key-value pairs to include in the connect command object.
    ///
    /// Used to pass platform-specific or custom properties such as
    /// `fourCcList` for Enhanced RTMP negotiation.
    public var additional: [(String, AMF0Value)]

    /// Creates connect properties with default values.
    ///
    /// - Parameters:
    ///   - app: Application name on the server.
    ///   - flashVer: Flash player version string.
    ///   - tcUrl: URL of the server application.
    ///   - type: Connection type.
    ///   - fpad: Whether proxy is used.
    ///   - capabilities: Audio/video capabilities.
    ///   - audioCodecs: Supported audio codecs bitmask.
    ///   - videoCodecs: Supported video codecs bitmask.
    ///   - videoFunction: Video function support.
    ///   - objectEncoding: AMF encoding version.
    public init(
        app: String,
        flashVer: String = "FMLE/3.0 (compatible; FMSc/1.0)",
        tcUrl: String,
        type: String = "nonprivate",
        fpad: Bool = false,
        capabilities: Double = 15,
        audioCodecs: Double = 0x0FFF,
        videoCodecs: Double = 0x00FF,
        videoFunction: Double = 1,
        objectEncoding: Double = 0
    ) {
        self.app = app
        self.flashVer = flashVer
        self.tcUrl = tcUrl
        self.type = type
        self.fpad = fpad
        self.capabilities = capabilities
        self.audioCodecs = audioCodecs
        self.videoCodecs = videoCodecs
        self.videoFunction = videoFunction
        self.objectEncoding = objectEncoding
        self.additional = []
    }

    /// Convert to AMF0 object value (preserving property order).
    ///
    /// - Returns: An AMF0 object with all properties in the canonical order.
    public func toAMF0() -> AMF0Value {
        var pairs: [(String, AMF0Value)] = [
            ("app", .string(app)),
            ("flashVer", .string(flashVer)),
            ("tcUrl", .string(tcUrl)),
            ("type", .string(type)),
            ("fpad", .boolean(fpad)),
            ("capabilities", .number(capabilities)),
            ("audioCodecs", .number(audioCodecs)),
            ("videoCodecs", .number(videoCodecs)),
            ("videoFunction", .number(videoFunction)),
            ("objectEncoding", .number(objectEncoding))
        ]
        for (key, value) in additional {
            pairs.append((key, value))
        }
        return .object(pairs)
    }

    /// Parse from an AMF0 object value.
    ///
    /// - Parameter value: An AMF0 object or null value.
    /// - Returns: Parsed connect properties with defaults for missing fields.
    public static func fromAMF0(_ value: AMF0Value) -> ConnectProperties {
        guard let pairs = value.objectProperties else {
            return ConnectProperties(app: "", tcUrl: "")
        }
        let dict = Dictionary(pairs, uniquingKeysWith: { _, last in last })
        var props = ConnectProperties(
            app: dict["app"]?.stringValue ?? "",
            tcUrl: dict["tcUrl"]?.stringValue ?? ""
        )
        if let v = dict["flashVer"]?.stringValue { props.flashVer = v }
        if let v = dict["type"]?.stringValue { props.type = v }
        if let v = dict["fpad"]?.booleanValue { props.fpad = v }
        if let v = dict["capabilities"]?.numberValue { props.capabilities = v }
        if let v = dict["audioCodecs"]?.numberValue { props.audioCodecs = v }
        if let v = dict["videoCodecs"]?.numberValue { props.videoCodecs = v }
        if let v = dict["videoFunction"]?.numberValue { props.videoFunction = v }
        if let v = dict["objectEncoding"]?.numberValue { props.objectEncoding = v }
        let knownKeys: Set<String> = [
            "app", "flashVer", "tcUrl", "type", "fpad",
            "capabilities", "audioCodecs", "videoCodecs",
            "videoFunction", "objectEncoding"
        ]
        for (key, val) in pairs where !knownKeys.contains(key) {
            props.additional.append((key, val))
        }
        return props
    }

    public static func == (lhs: ConnectProperties, rhs: ConnectProperties) -> Bool {
        lhs.app == rhs.app
            && lhs.flashVer == rhs.flashVer
            && lhs.tcUrl == rhs.tcUrl
            && lhs.type == rhs.type
            && lhs.fpad == rhs.fpad
            && lhs.capabilities == rhs.capabilities
            && lhs.audioCodecs == rhs.audioCodecs
            && lhs.videoCodecs == rhs.videoCodecs
            && lhs.videoFunction == rhs.videoFunction
            && lhs.objectEncoding == rhs.objectEncoding
    }
}
