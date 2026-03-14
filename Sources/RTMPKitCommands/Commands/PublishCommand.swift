// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import RTMPKit

/// Stream an FLV file to an RTMP server.
///
/// Usage:
///   rtmp-cli publish --url rtmps://live.twitch.tv/app --key <key> --file video.flv
///   rtmp-cli publish --preset twitch --key <key> --file video.flv
///   rtmp-cli publish --dest twitch:live_abc --dest youtube:yt-key --file video.flv
public struct PublishCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "publish",
        abstract: "Stream an FLV file to an RTMP server"
    )

    // MARK: - Arguments

    /// RTMP server URL.
    @Option(
        name: .long,
        help: "RTMP server URL (e.g., rtmps://live.twitch.tv/app)"
    )
    public var url: String?

    /// Platform preset (alternative to --url).
    @Option(
        name: .long,
        help: "Platform preset: twitch, youtube, facebook, kick"
    )
    public var preset: String?

    /// Stream key(s). Required with --url or --preset. Repeatable with --dest.
    @Option(name: .long, help: "Stream key (repeatable for multi-dest)")
    public var key: [String] = []

    /// FLV file to stream.
    @Option(name: .long, help: "Path to FLV file to stream")
    public var file: String

    /// Multi-destination targets in `platform:key` or `url:key` format.
    @Option(
        name: .long,
        help: "Destination (platform:key or url:key). Repeatable."
    )
    public var dest: [DestinationArgument] = []

    /// Twitch ingest server (only with --preset twitch).
    @Option(
        name: .long,
        help:
            "Twitch ingest server: auto, us-east, us-west, europe, asia"
    )
    public var ingest: String?

    /// Chunk size.
    @Option(name: .long, help: "RTMP chunk size")
    public var chunkSize: UInt32 = 4096

    /// Disable Enhanced RTMP.
    @Flag(
        name: .long,
        help: "Disable Enhanced RTMP v2 (force legacy mode, not recommended for HEVC/AV1/VP9)"
    )
    public var noEnhancedRTMP: Bool = false

    /// Loop playback.
    @Flag(name: .long, help: "Loop the file continuously")
    public var loop: Bool = false

    /// Quiet mode (no progress display).
    @Flag(name: .long, help: "Suppress progress output")
    public var quiet: Bool = false

    /// Prometheus metrics output file.
    @Option(
        name: .long,
        help: "Write Prometheus metrics to file every 10s"
    )
    public var metricsPrometheus: String?

    /// StatsD server (host:port) for metrics push.
    @Option(
        name: .long,
        help: "Push metrics to StatsD (host:port)"
    )
    public var metricsStatsd: String?

    /// Username for Adobe challenge/response or simple auth.
    @Option(name: .long, help: "Auth username (Adobe or simple)")
    public var authUser: String?

    /// Password for Adobe challenge/response or simple auth.
    @Option(name: .long, help: "Auth password (Adobe or simple)")
    public var authPass: String?

    public init() {}

    // MARK: - Validation

    public func validate() throws {
        let hasURLOrPreset = url != nil || preset != nil
        let hasDest = !dest.isEmpty

        guard hasURLOrPreset || hasDest else {
            throw ValidationError(
                "Either --url/--preset or --dest is required"
            )
        }
        if hasURLOrPreset {
            guard !key.isEmpty else {
                throw ValidationError(
                    "--key is required with --url or --preset"
                )
            }
        }
        guard !(url != nil && preset != nil) else {
            throw ValidationError(
                "Cannot specify both --url and --preset"
            )
        }
        if ingest != nil && preset != "twitch" {
            throw ValidationError(
                "--ingest is only valid with --preset twitch"
            )
        }
    }

    // MARK: - Run

    public mutating func run() async throws {
        let display = ProgressDisplay()

        let reader: MediaFileReader
        do {
            reader = try MediaFileReader(path: file)
        } catch let error as MediaFileReaderError {
            display.showError(
                "Failed to open file: \(error.description)"
            )
            throw ExitCode.failure
        } catch {
            display.showError(
                "Failed to open file: \(error)"
            )
            throw ExitCode.failure
        }

        let codecInfo = reader.codecInfo

        if !quiet {
            display.showStatus("File: \(file)")
            if codecInfo.videoCodec.requiresEnhancedRTMP {
                display.showStatus(
                    "Video: \(codecInfo.videoCodec.displayName)"
                        + " — Enhanced RTMP v2 will be used"
                )
            } else {
                display.showStatus(
                    "Video: \(codecInfo.videoCodec.displayName)"
                )
            }
            display.showStatus(
                "Audio: \(codecInfo.audioCodec.displayName)"
            )
        }

        if noEnhancedRTMP && codecInfo.videoCodec.requiresEnhancedRTMP {
            display.showWarning(
                "Enhanced RTMP disabled —"
                    + " \(codecInfo.videoCodec.displayName) stream"
                    + " may not be supported by server"
            )
        }

        let destinations = try buildDestinations(codecInfo: codecInfo)

        if destinations.count == 1 {
            try await runSingleDestination(
                config: destinations[0].configuration,
                reader: reader,
                display: display
            )
        } else {
            try await runMultiDestination(
                destinations: destinations,
                reader: reader,
                display: display
            )
        }
    }

    // MARK: - Configuration

    /// Build the list of all publishing destinations.
    func buildDestinations(
        codecInfo: FLVCodecInfo = FLVCodecInfo(
            videoCodec: .unknown, audioCodec: .unknown
        )
    ) throws -> [PublishDestination] {
        var destinations: [PublishDestination] = []
        let useEnhanced = resolveEnhancedRTMP(codecInfo: codecInfo)

        if url != nil || preset != nil {
            let config = try buildConfiguration(
                enhancedRTMP: useEnhanced
            )
            destinations.append(
                PublishDestination(id: "primary", configuration: config)
            )
        }

        for (i, d) in dest.enumerated() {
            var config = d.configuration
            var destID = d.id
            // If dest has no embedded key, pair with --key[i]
            if config.streamKey.isEmpty, i < key.count {
                config = RTMPConfiguration(
                    url: config.url,
                    streamKey: key[i],
                    chunkSize: chunkSize,
                    enhancedRTMP: useEnhanced
                )
                destID = "\(config.url)/\(key[i])"
            }
            destinations.append(
                PublishDestination(id: destID, configuration: config)
            )
        }

        return destinations
    }

    func buildConfiguration(
        enhancedRTMP: Bool? = nil
    ) throws -> RTMPConfiguration {
        let useEnhanced = enhancedRTMP ?? !noEnhancedRTMP
        guard let key = key.first else {
            throw ValidationError(
                "--key is required with --url or --preset"
            )
        }
        if let preset {
            let ingestServer = parseIngestServer()
            switch preset.lowercased() {
            case "twitch":
                return .twitch(
                    streamKey: key,
                    ingestServer: ingestServer ?? .auto
                )
            case "youtube":
                return .youtube(streamKey: key)
            case "facebook":
                return .facebook(streamKey: key)
            case "kick":
                return .kick(streamKey: key)
            default:
                throw ValidationError(
                    "Unknown preset: \(preset)"
                )
            }
        }
        guard let url else {
            throw ValidationError(
                "Either --url or --preset is required"
            )
        }
        var config = RTMPConfiguration(
            url: url,
            streamKey: key,
            chunkSize: chunkSize,
            enhancedRTMP: useEnhanced
        )
        if let authUser, let authPass {
            config.authentication = .adobeChallenge(
                username: authUser, password: authPass
            )
        }
        return config
    }

    /// Resolve whether Enhanced RTMP should be enabled.
    ///
    /// Auto-enables when non-H.264 codecs are detected, unless
    /// `--no-enhanced-rtmp` is explicitly set.
    func resolveEnhancedRTMP(codecInfo: FLVCodecInfo) -> Bool {
        if noEnhancedRTMP {
            return false
        }
        return codecInfo.videoCodec.requiresEnhancedRTMP
    }

    func parseIngestServer() -> TwitchIngestServer? {
        guard let ingest else { return nil }
        switch ingest.lowercased() {
        case "auto": return .auto
        case "us-east": return .usEast
        case "us-west": return .usWest
        case "europe": return .europe
        case "asia": return .asia
        case "south-america": return .southAmerica
        case "australia": return .australia
        default: return nil
        }
    }
}

// MARK: - Streaming

extension PublishCommand {

    fileprivate func runSingleDestination(
        config: RTMPConfiguration,
        reader: MediaFileReader,
        display: ProgressDisplay
    ) async throws {
        if !quiet {
            display.showStatus("Connecting to \(config.url)...")
        }

        let publisher = RTMPPublisher()

        // Wire metrics exporters
        if let promPath = metricsPrometheus {
            let exporter = PrometheusExporter(outputPath: promPath)
            await publisher.setMetricsExporter(exporter)
        } else if let statsdArg = metricsStatsd {
            let parts = statsdArg.split(separator: ":", maxSplits: 1)
            let host = parts.count > 0 ? String(parts[0]) : "127.0.0.1"
            let port = parts.count > 1 ? Int(parts[1]) ?? 8125 : 8125
            let exporter = StatsDExporter(host: host, port: port)
            await publisher.setMetricsExporter(exporter)
        }

        do {
            try await publisher.publish(configuration: config)
        } catch let error as RTMPError {
            display.showError(error.description)
            throw ExitCode.failure
        } catch {
            display.showError("\(error)")
            throw ExitCode.failure
        }

        if !quiet {
            display.showSuccess("Connected — publishing")
        }

        do {
            try await streamTags(
                reader: reader,
                publisher: publisher,
                display: quiet ? nil : display
            )
        } catch let error as RTMPError {
            display.showError(error.description)
            await publisher.flushMetrics()
            await publisher.disconnect()
            throw ExitCode.failure
        } catch {
            display.showError("\(error)")
            await publisher.flushMetrics()
            await publisher.disconnect()
            throw ExitCode.failure
        }

        if !quiet {
            print()
            display.showSuccess("Streaming complete")
        }

        await publisher.flushMetrics()
        await publisher.disconnect()
    }

    fileprivate func runMultiDestination(
        destinations: [PublishDestination],
        reader: MediaFileReader,
        display: ProgressDisplay
    ) async throws {
        let multi = MultiPublisher()

        for destination in destinations {
            try await multi.addDestination(destination)
            if !quiet {
                display.showStatus(
                    "[\(destination.id)] Added"
                )
            }
        }

        if !quiet {
            display.showStatus(
                "Starting \(destinations.count) destinations..."
            )
        }

        await multi.startAll()

        if !quiet {
            let states = await multi.destinationStates
            for (id, state) in states {
                display.showStatus("[\(id)] \(state)")
            }
        }

        do {
            try await streamTagsMulti(
                reader: reader,
                multi: multi,
                display: quiet ? nil : display
            )
        } catch {
            display.showError("\(error)")
            await multi.stopAll()
            throw ExitCode.failure
        }

        if !quiet {
            print()
            display.showSuccess(
                "Streaming complete to \(destinations.count) destinations"
            )
        }

        await multi.stopAll()
    }

    fileprivate func streamTagsMulti(
        reader: MediaFileReader,
        multi: MultiPublisher,
        display: ProgressDisplay?
    ) async throws {
        var tags = reader.tags()
        var baseTime: UInt64 = 0
        var sentFirstAudio = false
        var sentFirstVideo = false

        while let tag = tags.next() {
            if tag.timestamp > 0 {
                let delayMs = UInt64(tag.timestamp) - baseTime
                if delayMs > 0 {
                    try await Task.sleep(
                        nanoseconds: delayMs * 1_000_000
                    )
                }
                baseTime = UInt64(tag.timestamp)
            }

            if tag.isScript {
                await multi.sendRawDataMessage(tag.data)
            } else if tag.isAudio {
                if !sentFirstAudio
                    && Self.isAudioConfig(tag.data)
                {
                    await multi.sendAudioConfigPayload(tag.data)
                    sentFirstAudio = true
                } else {
                    await multi.sendAudioPayload(
                        tag.data, timestamp: tag.timestamp
                    )
                }
            } else if tag.isVideo {
                if !sentFirstVideo
                    && Self.isVideoConfig(tag.data)
                {
                    await multi.sendVideoConfigPayload(tag.data)
                    sentFirstVideo = true
                } else {
                    let isKF = Self.isKeyframe(tag.data)
                    await multi.sendVideoPayload(
                        tag.data,
                        timestamp: tag.timestamp,
                        isKeyframe: isKF
                    )
                }
            }

            if display != nil {
                let stats = await multi.statistics
                let sent = ProgressDisplay.formatBytes(
                    UInt64(stats.totalBytesSent)
                )
                let active = stats.activeCount
                print(
                    "\r[\(active) active] \(sent) sent",
                    terminator: ""
                )
                fflush(nil)
            }
        }
    }

    fileprivate func streamTags(
        reader: MediaFileReader,
        publisher: RTMPPublisher,
        display: ProgressDisplay?
    ) async throws {
        var tags = reader.tags()
        var baseTime: UInt64 = 0
        var sentFirstAudio = false
        var sentFirstVideo = false

        while let tag = tags.next() {
            if tag.timestamp > 0 {
                let delayMs = UInt64(tag.timestamp) - baseTime
                if delayMs > 0 {
                    try await Task.sleep(
                        nanoseconds: delayMs * 1_000_000
                    )
                }
                baseTime = UInt64(tag.timestamp)
            }

            if tag.isScript {
                try await publisher.sendDataMessagePayload(tag.data)
            } else if tag.isAudio {
                if !sentFirstAudio
                    && Self.isAudioConfig(tag.data)
                {
                    try await publisher.sendAudioConfigPayload(
                        tag.data
                    )
                    sentFirstAudio = true
                } else {
                    try await publisher.sendAudioPayload(
                        tag.data, timestamp: tag.timestamp
                    )
                }
            } else if tag.isVideo {
                if !sentFirstVideo
                    && Self.isVideoConfig(tag.data)
                {
                    try await publisher.sendVideoConfigPayload(
                        tag.data
                    )
                    sentFirstVideo = true
                } else {
                    let isKF = Self.isKeyframe(tag.data)
                    try await publisher.sendVideoPayload(
                        tag.data,
                        timestamp: tag.timestamp,
                        isKeyframe: isKF
                    )
                }
            }

            if let display {
                let stats = await publisher.statistics
                let state = await publisher.state
                display.update(
                    statistics: stats,
                    state: state,
                    elapsed: stats.connectionUptime
                )
            }
        }
    }

    // MARK: - FLV Tag Detection Helpers

    /// Detect if a video tag payload is a keyframe.
    ///
    /// Handles both legacy AVC (upper nibble = 1) and Enhanced RTMP
    /// (bits 4-6 = frameType) formats.
    static func isKeyframe(_ data: [UInt8]) -> Bool {
        guard let byte0 = data.first else { return false }
        if ExVideoHeader.isExHeader(byte0) {
            return ((byte0 >> 4) & 0x07) == VideoFrameType.keyFrame.rawValue
        }
        return (byte0 & 0xF0) == 0x10
    }

    /// Detect if a video tag payload is a config/sequence header.
    ///
    /// Legacy AVC: byte[1] == 0x00 (AVCPacketType == sequence header).
    /// Enhanced RTMP: packetType == sequenceStart in low nibble of byte 0.
    static func isVideoConfig(_ data: [UInt8]) -> Bool {
        guard !data.isEmpty else { return false }
        let byte0 = data[0]
        if ExVideoHeader.isExHeader(byte0) {
            let packetType = byte0 & 0x0F
            return packetType == ExVideoPacketType.sequenceStart.rawValue
        }
        return data.count >= 2 && data[1] == 0x00
    }

    /// Detect if an audio tag payload is a config/sequence header.
    ///
    /// Legacy AAC: SoundFormat=10 (upper nibble = 0xA) AND byte[1] == 0x00.
    /// Enhanced RTMP: non-legacy SoundFormat with bit 7 set, packetType == sequenceStart.
    static func isAudioConfig(_ data: [UInt8]) -> Bool {
        guard !data.isEmpty else { return false }
        let byte0 = data[0]
        // Check legacy AAC first (SoundFormat=10, upper nibble = 0xA).
        // 0xAF also has bit 7 set, so we must check legacy before enhanced.
        let soundFormat = (byte0 >> 4) & 0x0F
        if soundFormat == 10 {
            return data.count >= 2 && data[1] == 0x00
        }
        if ExAudioHeader.isExHeader(byte0) {
            let packetType = (byte0 >> 3) & 0x0F
            return packetType == ExAudioPacketType.sequenceStart.rawValue
        }
        return false
    }
}
