# swift-rtmp-kit

[![CI](https://github.com/atelier-socle/swift-rtmp-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/atelier-socle/swift-rtmp-kit/actions/workflows/ci.yml)
[![codecov](https://codecov.io/github/atelier-socle/swift-rtmp-kit/graph/badge.svg?token=IAM0DCG6WW)](https://codecov.io/github/atelier-socle/swift-rtmp-kit)
[![Documentation](https://img.shields.io/badge/DocC-Documentation-blue)](https://atelier-socle.github.io/swift-rtmp-kit/documentation/rtmpkit/)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS%20|%20Linux-lightgray)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

![swift-rtmp-kit](./assets/banner.png)

Pure Swift RTMP publish client for live streaming to Twitch, YouTube, Facebook, Kick, Instagram, TikTok, Rumble, and any RTMP server. Enhanced RTMP v2 with auto-detection for HEVC, AV1, VP9, and Opus. Adaptive bitrate, multi-destination publishing, stream recording, authentication, bandwidth probing, connection quality scoring, Prometheus/StatsD metrics, and full RTMP ingest server. Zero dependencies on the core target. Strict `Sendable` conformance throughout. Part of the [Atelier Socle](https://www.atelier-socle.com) streaming ecosystem.

---

## Features

- **Full RTMP 1.0 protocol** — Handshake (C0/C1/C2), chunk stream multiplexing with fmt1/fmt2/fmt3 header compression, AMF0 commands, FLV packaging
- **Enhanced RTMP v2** — FourCC codec negotiation for HEVC, AV1, VP9, Opus, FLAC, AC-3, and E-AC-3 with auto-detection from FLV files. Validated E2E with SRS v6 and MediaMTX
- **A/V timestamp interleaving** — Audio and video chunks sent in timestamp order, matching FFmpeg's interleaving pattern
- **FLV packaging** — Audio tags (AAC sequence headers, raw frames), video tags (AVC NALUs, keyframes), script data
- **10 platform presets** — One-line configuration for Twitch, YouTube, Facebook, Kick, Instagram, TikTok, Rumble, LinkedIn, Trovo, and Twitter/Periscope
- **Streaming platform registry** — Programmatic discovery with case-insensitive lookup, TLS-required filtering, and dynamic configuration
- **Adaptive bitrate** — Conservative, responsive, and aggressive ABR policies with EWMA bandwidth estimation, RTT tracking, congestion detection, and frame dropping
- **Multi-destination publishing** — Stream simultaneously to N servers with per-destination state, failure isolation, hot add/remove, and configurable failure policies
- **RTMP authentication** — Simple (query string), token with expiry, and Adobe MD5 challenge/response (Wowza)
- **FLV codec auto-detection** — HEVC, AV1, VP9, and Opus detected automatically from FLV files; Enhanced RTMP v2 enabled transparently
- **Stream recording** — Record live streams to FLV with segmentation, pause/resume, and size limits
- **Bandwidth probing** — Measure bandwidth, RTT jitter, packet loss, and get 6-tier quality preset recommendations
- **Connection quality scoring** — Composite quality grades (excellent/good/fair/poor/critical) with 5 weighted dimensions and trend analysis
- **Dynamic metadata** — `@setDataFrame`/`onMetaData` during streaming, timed text, cue points with rich parameters, and captions with multiple standards
- **AMF3 support** — Full AMF3 encoding and decoding for all 18 type markers with 3 reference tables (string/object/traits)
- **Prometheus and StatsD metrics** — Export publisher and server metrics to monitoring systems with periodic or on-demand snapshots
- **RTMP ingest server** — Accept inbound RTMP connections with stream key validation (allow-list, closure-based), relay to multiple destinations, and DVR recording
- **Server security** — IP blocklist/allowlist, temporary bans, rate limiting per IP, and configurable security policies (open/standard/strict)
- **Auto-reconnection** — Exponential backoff with configurable jitter, retry limits, and four presets (`.default`, `.aggressive`, `.conservative`, `.none`)
- **Real-time monitoring** — `AsyncStream`-based event bus, ConnectionMonitor with sliding-window bitrate, dropped frame tracking, and RTT measurement
- **Transport dependency injection** — Replace the NIO transport with a mock for testing without a real RTMP server
- **Cross-platform** — macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1+, and Linux (Swift 6.2+)
- **CLI tool** — `rtmp-cli` for streaming, recording, probing, server management, and diagnostics
- **Swift 6.2 strict concurrency** — Actors for stateful types, `Sendable` everywhere, `async`/`await` throughout, zero `@unchecked Sendable` or `nonisolated(unsafe)`
- **Server compatibility** — Tested with MediaMTX, SRS v6, nginx-rtmp, and Wowza. Handles bandwidth commands (`onBWDone`, `onBWCheck`) sent by SRS and Wowza
- **Low-latency transport** — TCP_NODELAY enabled by default, fire-and-forget monitoring off the critical send path
- **Zero core dependencies** — The `RTMPKit` target depends only on SwiftNIO for the transport layer. No other third-party dependencies

---

## Standards

| Standard | Reference |
|----------|-----------|
| RTMP 1.0 | [Adobe RTMP Specification (PDF)](https://veovera.github.io/enhanced-rtmp/docs/legacy/rtmp-v1-0-spec.pdf) |
| Enhanced RTMP v2 | [Veovera Enhanced RTMP (GitHub)](https://github.com/veovera/enhanced-rtmp) |
| AMF0 | [Adobe AMF0 Specification (PDF)](https://veovera.github.io/enhanced-rtmp/docs/legacy/amf0-file-format-spec.pdf) |
| AMF3 | [Adobe AMF3 Specification (PDF)](https://veovera.github.io/enhanced-rtmp/docs/legacy/amf3-file-format-spec.pdf) |
| FLV File Format | [Adobe FLV/F4V Specification v10.1 (PDF)](https://veovera.github.io/enhanced-rtmp/docs/legacy/video-file-format-v10-1-spec.pdf) |

---

## Quick Start

Connect to Twitch, send audio/video data, and disconnect gracefully:

```swift
import RTMPKit

// 1. Create a Twitch configuration
let config = RTMPConfiguration.twitch(streamKey: "live_abc123")

// 2. Create the publisher
let publisher = RTMPPublisher()

// 3. Connect and start publishing
try await publisher.publish(configuration: config)

// 4. Send codec configuration (sequence headers)
try await publisher.sendAudioConfig(aacSequenceHeader)
try await publisher.sendVideoConfig(avcSequenceHeader)

// 5. Send audio and video frames
try await publisher.sendAudio(aacFrame, timestamp: 0)
try await publisher.sendVideo(naluData, timestamp: 0, isKeyframe: true)

// 6. Disconnect when done
await publisher.disconnect()
```

---

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/swift-rtmp-kit.git", from: "0.3.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["RTMPKit"]
)
```

---

## Platform Support

| Platform | Minimum Version |
|----------|----------------|
| macOS | 14+ |
| iOS | 17+ |
| tvOS | 17+ |
| watchOS | 10+ |
| visionOS | 1+ |
| Linux | Swift 6.2 (Ubuntu 22.04+) |

---

## Usage

### Platform Presets

One-line configuration for 10 streaming platforms:

```swift
// Twitch — RTMPS, Enhanced RTMP enabled
let twitch = RTMPConfiguration.twitch(streamKey: "live_abc123")

// Twitch with specific ingest server
let twitchEU = RTMPConfiguration.twitch(
    streamKey: "live_eu_key",
    ingestServer: .europe
)

// YouTube — RTMPS, Enhanced RTMP enabled
let youtube = RTMPConfiguration.youtube(streamKey: "xxxx-xxxx-xxxx-xxxx")

// Facebook — RTMPS, Enhanced RTMP disabled
let facebook = RTMPConfiguration.facebook(streamKey: "FB-xxxx")

// Kick — Enhanced RTMP disabled
let kick = RTMPConfiguration.kick(streamKey: "kick_key_123")

// Instagram — RTMPS required, no Enhanced RTMP
let instagram = RTMPConfiguration.instagram(streamKey: "IGLive_abc123")

// TikTok — RTMPS required
let tiktok = RTMPConfiguration.tiktok(streamKey: "tiktok_stream_key")

// Rumble — plain RTMP (no TLS)
let rumble = RTMPConfiguration.rumble(streamKey: "my_rumble_key")
```

### Streaming Platform Registry

Discover and configure all 10 platforms programmatically:

```swift
// Case-insensitive lookup
let preset = StreamingPlatformRegistry.platform(named: "LinkedIn")  // .linkedin
let preset2 = StreamingPlatformRegistry.platform(named: "TROVO")    // .trovo

// Create configuration from platform name
let config = StreamingPlatformRegistry.configuration(
    platform: "twitter", streamKey: "periscope_key"
)

// Iterate all platforms
for preset in StreamingPlatformRegistry.allPlatforms {
    let config = StreamingPlatformRegistry.configuration(
        platform: preset.name, streamKey: "test_key"
    )
    print("\(preset.name): \(config?.url ?? "N/A")")
}

// List TLS-required platforms
for preset in StreamingPlatformRegistry.tlsRequiredPlatforms {
    // All use rtmps://
}
```

### Custom Configuration

For any RTMP server:

```swift
let config = RTMPConfiguration(
    url: "rtmp://custom.server.com/app",
    streamKey: "mykey",
    chunkSize: 8192,
    enhancedRTMP: true,
    reconnectPolicy: .aggressive,
    flashVersion: "CustomEncoder/1.0",
    transportConfiguration: .lowLatency
)

let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)
```

### Event Monitoring

Subscribe to the `AsyncStream`-based event bus to observe state changes, server messages, and periodic statistics:

```swift
let eventTask = Task {
    for await event in publisher.events {
        switch event {
        case .stateChanged(let state):
            print("State: \(state)")
        case .serverMessage(let code, let description):
            print("Server: \(code) — \(description)")
        case .statisticsUpdate(let stats):
            print("Bitrate: \(stats.currentBitrate) bps")
        case .bitrateRecommendation(let rec):
            print("ABR: \(rec.previousBitrate) → \(rec.recommendedBitrate)")
        case .qualityWarning(let score):
            print("Quality: \(score.grade)")
        case .recordingEvent(let event):
            print("Recording: \(event)")
        case .error(let error):
            print("Error: \(error)")
        default:
            break
        }
    }
}
```

### Connection Statistics

Access real-time statistics at any point:

```swift
let stats = await publisher.statistics
print("Bytes sent: \(stats.bytesSent)")
print("Frames: \(stats.totalFramesSent)")
print("Bitrate: \(stats.currentBitrate) bps")
print("Uptime: \(stats.connectionUptime)s")
print("Drop rate: \(stats.dropRate)%")
```

### Auto-Reconnection

Configure automatic reconnection with exponential backoff:

```swift
// Default: 5 retries, 1s initial, 2x backoff, 30s max
let config = RTMPConfiguration(
    url: "rtmp://server/app",
    streamKey: "key",
    reconnectPolicy: .default
)

// Aggressive: 10 retries, 0.5s initial, 1.5x backoff
let aggressive = RTMPConfiguration(
    url: "rtmp://server/app",
    streamKey: "key",
    reconnectPolicy: .aggressive
)

// Custom policy
let custom = ReconnectPolicy(
    maxAttempts: 20,
    initialDelay: 0.1,
    maxDelay: 10.0,
    multiplier: 1.5,
    jitter: 0.1
)
```

### Enhanced RTMP v2

Enhanced RTMP is enabled by default. After connecting, check which codecs were negotiated:

```swift
let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)

let info = await publisher.serverInfo
if info.enhancedRTMP {
    let codecs = info.negotiatedCodecs.map(\.stringValue)
    print("Enhanced RTMP: \(codecs.joined(separator: ", "))")
}
```

Build enhanced video/audio tags for modern codecs:

```swift
// HEVC video
let seqHeader = FLVVideoTag.enhancedSequenceStart(fourCC: .hevc, config: hevcConfig)
let frame = FLVVideoTag.enhancedCodedFrames(
    fourCC: .hevc, data: naluData, isKeyframe: true, cts: 33
)

// Opus audio
let audioSeq = FLVAudioTag.enhancedSequenceStart(fourCC: .opus, config: opusConfig)
let audioFrame = FLVAudioTag.enhancedCodedFrame(fourCC: .opus, data: opusData)
```

### HEVC Auto-Detection

```swift
// Auto-detect codecs from FLV file
let codecInfo = FLVCodecProbe.probe(data: flvBytes, dataOffset: 13)
print("Video: \(codecInfo.videoCodec.displayName)")
print("Audio: \(codecInfo.audioCodec.displayName)")

if codecInfo.videoCodec.requiresEnhancedRTMP {
    print("Enhanced RTMP v2 will be used")
}
```

### Multi-Destination Publishing

Stream to multiple platforms simultaneously with failure isolation:

```swift
let multi = MultiPublisher()
try await multi.addDestination(PublishDestination(
    id: "twitch",
    configuration: .twitch(streamKey: "live_xxx")
))
try await multi.addDestination(PublishDestination(
    id: "youtube",
    configuration: .youtube(streamKey: "xxxx-xxxx-xxxx-xxxx")
))
try await multi.addDestination(PublishDestination(
    id: "facebook",
    configuration: .facebook(streamKey: "FB-zzz")
))

// Connect all destinations
await multi.startAll()

// Send A/V to all active destinations
await multi.sendVideo(naluData, timestamp: 0, isKeyframe: true)
await multi.sendAudio(aacFrame, timestamp: 0)

// Send metadata to all destinations
await multi.sendMetadata(streamMeta)
await multi.sendText("Now playing", timestamp: 10.0)

// Per-destination statistics
let stats = await multi.statistics
print("Active: \(stats.activeCount), bytes: \(stats.totalBytesSent)")

// Hot add/remove during streaming
try await multi.addDestination(
    PublishDestination(id: "custom", url: "rtmp://server/app", streamKey: "key")
)
try await multi.removeDestination(id: "custom")

// Failure policies
await multi.setFailurePolicy(.stopAllOnFailure(count: 2))

await multi.stopAll()
```

### Adaptive Bitrate

Three preset ABR policies with configurable min/max bitrate:

```swift
var config = RTMPConfiguration.twitch(streamKey: "live_xxx")
config.adaptiveBitrate = .responsive(min: 1_000_000, max: 6_000_000)
// .conservative: stepDown 0.80, slow recovery (live events)
// .responsive: stepDown 0.75, balanced (gaming, sport)
// .aggressive: stepDown 0.65, fast (casual streaming)

let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)

// Read current bitrate
let bitrate = await publisher.currentVideoBitrate

// Force manual override
await publisher.forceVideoBitrate(2_000_000)

// Frame dropping: B-frames → P-frames (I-frames never dropped)
config.frameDroppingStrategy = .aggressive  // or .conservative, .default
```

### Authentication

```swift
// Simple auth — appends credentials to URL
var config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
config.authentication = .simple(username: "user", password: "pass")

// Adobe challenge/response (Wowza) — automatic two-round handshake
config.authentication = .adobeChallenge(username: "broadcaster", password: "s3cr3t")

// Token auth with expiry — throws RTMPError.tokenExpired if expired
config.authentication = .token("eyJhbGciOiJ...", expiry: Date().addingTimeInterval(3600))
```

### Stream Recording

Record live streams to FLV with segmentation and size limits:

```swift
let recorder = StreamRecorder(configuration: RecordingConfiguration(
    format: .flv,
    outputDirectory: "/tmp/recordings",
    baseFilename: "stream",
    segmentDuration: 300,       // 5-minute segments
    maxTotalSize: 500_000_000   // 500 MB total limit
))
try await recorder.start()

// Write frames
try await recorder.writeVideo(videoBytes, timestamp: 0, isKeyframe: true)
try await recorder.writeAudio(audioBytes, timestamp: 0)

// Pause/resume
await recorder.pause()
await recorder.resume()

// Stop and get segment info
let segment = try await recorder.stop()

// Or record through the publisher
try await publisher.startRecording(configuration: recordingConfig)
let segment = try await publisher.stopRecording()
```

### Bandwidth Probing

Measure connection quality before streaming:

```swift
let probe = BandwidthProbe(
    configuration: .init(duration: 0.3, burstInterval: 0.05, warmupBursts: 1)
)
let result = try await probe.probe(url: "rtmp://server/app")
print("Bandwidth: \(result.estimatedBandwidth) bps")
print("Signal quality: \(result.signalQuality)")
print("Summary: \(result.summary)")

// Auto-select quality preset for platform
let config = QualityPresetSelector.select(
    for: result, platform: .twitch(.auto), streamKey: "live_xxx"
)
// 6-tier quality ladder: 360p30 → 480p30 → 720p30 → 720p60 → 1080p30 → 1080p60
```

### Connection Quality Scoring

Monitor connection health with composite grades:

```swift
let monitor = ConnectionQualityMonitor(
    scoringInterval: 0.05, reportingWindow: 5.0
)
await monitor.start()

await monitor.recordRTT(15.0)
await monitor.recordBytesSent(500_000, targetBitrate: 4_000_000)

var iterator = await monitor.scores.makeAsyncIterator()
let score = await iterator.next()
// score?.grade — .excellent, .good, .fair, .poor, .critical

let report = await monitor.generateReport()
// report?.trend — .improving, .stable, .degrading
```

### Dynamic Metadata

```swift
// Stream metadata with factory methods
let meta = StreamMetadata.h264AAC(
    width: 1920, height: 1080, frameRate: 30,
    videoBitrate: 4_500_000, audioBitrate: 128_000
)
try await publisher.updateStreamInfo(meta)

// Timed metadata: text, cue points, captions
try await publisher.send(.text("hello", timestamp: 0))
try await publisher.send(.cuePoint(CuePoint(
    name: "ad-break", time: 30000, type: .event,
    parameters: ["duration": .number(15), "sponsor": .string("acme")]
)))
try await publisher.send(.caption(CaptionData(text: "subtitle", timestamp: 2000)))

// Custom fields survive AMF0 roundtrip
var meta = StreamMetadata()
meta.customFields["copyright"] = .string("2026 Acme")
```

### Prometheus and StatsD Metrics

```swift
// Prometheus text format
let exporter = PrometheusExporter(prefix: "rtmp")
let output = exporter.render(stats, labels: ["env": "production"])
// rtmp_bytes_sent_total{env="production",platform="twitch"} 52428800

// StatsD packet format
let statsd = StatsDExporter(prefix: "rtmp")
let lines = statsd.buildPacket(stats)
// rtmp.video_bitrate_bps:4200000|g

// Wire periodic export to publisher
await publisher.setMetricsExporter(exporter, interval: 10.0)

// On-demand snapshot
let snapshot = await publisher.metricsSnapshot()
```

```bash
# CLI: Prometheus file output
rtmp-cli publish --url rtmp://server/app --key key --file stream.flv \
  --metrics-prometheus /tmp/metrics.txt

# CLI: StatsD UDP output
rtmp-cli publish --url rtmp://server/app --key key --file stream.flv \
  --metrics-statsd localhost:8125
```

### RTMP Ingest Server

Accept inbound RTMP connections with stream key validation, relay, and DVR:

```swift
// Basic server
let server = RTMPServer(configuration: .localhost)
try await server.start()
// state == .running(port: 1935)

// Accept publisher connections
let session = await server.acceptConnection()
let streamName = await session.streamName

// Stream key validation
let config = RTMPServerConfiguration(
    host: "127.0.0.1",
    streamKeyValidator: AllowListStreamKeyValidator(
        allowedKeys: ["live_abc123", "stream_xyz"]
    )
)

// Closure-based validation for dynamic auth
let validator = ClosureStreamKeyValidator { key, app in
    key.hasPrefix("live_") && app == "live"
}

// Relay to multiple destinations
let relay = RTMPStreamRelay(
    destinations: [
        .init(id: "twitch", configuration: .twitch(streamKey: "live_xxx")),
        .init(id: "youtube", configuration: .youtube(streamKey: "yyyy-yyyy"))
    ]
)
try await relay.start()
await server.attachRelay(relay, toStream: "live/myStream")

// DVR recording
let dvr = RTMPStreamDVR(configuration: RecordingConfiguration(
    outputDirectory: "/tmp/dvr"
))
try await dvr.start()
await server.attachDVR(dvr, toStream: "live/myStream")

// Auto-DVR: record all ingest streams automatically
let autoDVRConfig = RTMPServerConfiguration(
    host: "127.0.0.1",
    autoDVR: true,
    dvrConfiguration: RecordingConfiguration(outputDirectory: "/tmp/dvr")
)

// Server security
let policy = RTMPServerSecurityPolicy(
    streamKeyValidator: AllowListStreamKeyValidator(allowedKeys: ["live_abc"]),
    rateLimiter: RTMPConnectionRateLimiter(maxConnectionsPerIPPerMinute: 5),
    maxStreamDuration: 3600
)
// Presets: .open, .standard, .strict

// Access control
let ac = RTMPServerAccessControl()
await ac.addToBlocklist("192.168.1.100")
await ac.ban("10.0.0.1", duration: 60)

await server.stop()
```

### Transport Dependency Injection

Replace the real network with a mock for testing:

```swift
let mock = MockTransport()
mock.scriptedMessages = [ackMessage]

let publisher = RTMPPublisher(transport: mock)
// Test your publish logic without network access
```

---

## CLI

`rtmp-cli` provides command-line streaming, connection testing, and server diagnostics.

### Installation

```bash
swift build -c release
cp .build/release/rtmp-cli /usr/local/bin/
```

### Commands

| Command | Description |
|---------|-------------|
| `publish` | Stream an FLV file to one or more RTMP servers |
| `test-connection` | Test connectivity, handshake, and measure latency |
| `info` | Query server information, capabilities, and Enhanced RTMP support |
| `probe` | Measure bandwidth and connection quality |
| `record` | Publish an FLV file and record the stream to disk |
| `server` | Start a local RTMP ingest server |

### Examples

```bash
# Stream to Twitch
rtmp-cli publish --preset twitch --key live_xxx --file stream.flv

# Multi-destination: Twitch + YouTube
rtmp-cli publish --file stream.flv --dest twitch:live_xxx --dest youtube:xxxx-xxxx

# HEVC auto-detection (Enhanced RTMP enabled transparently)
rtmp-cli publish --url rtmp://server/app --key key --file hevc_stream.flv

# Adobe authentication
rtmp-cli publish --url rtmp://wowza.server.com/live --key stream \
  --auth-user broadcaster --auth-pass s3cr3t --file stream.flv

# Probe bandwidth
rtmp-cli probe rtmp://server:1935/live --thorough --platform twitch

# Record a stream
rtmp-cli record stream.flv --url rtmp://server/app --key key --output /tmp/recordings

# Start a local ingest server with DVR
rtmp-cli server start --port 1935 --allow-key mykey --dvr /tmp/dvr

# Test connection
rtmp-cli test-connection --preset twitch --key live_xxx

# Query server info
rtmp-cli info --url rtmp://localhost:1935/live --key test --json

# Prometheus metrics
rtmp-cli publish --url rtmp://server/app --key key --file stream.flv \
  --metrics-prometheus /tmp/metrics.txt

# StatsD metrics
rtmp-cli publish --url rtmp://server/app --key key --file stream.flv \
  --metrics-statsd localhost:8125
```

See the [CLI Reference](https://atelier-socle.github.io/swift-rtmp-kit/documentation/rtmpkit/clireference) for the full command documentation with all options and flags.

---

## Architecture

```
Sources/
├── RTMPKit/                     # Core library (NIO transport)
│   ├── AdaptiveBitrate/         # ABR policies, network monitor, frame dropping
│   ├── AMF/                     # AMF0 + AMF3 encoder/decoder
│   ├── Authentication/          # Simple, token, Adobe challenge/response auth
│   ├── Chunk/                   # Chunk stream multiplexing and assembly
│   ├── Configuration/           # RTMPConfiguration, platform presets, reconnect policy
│   ├── Enhanced/                # Enhanced RTMP v2 (FourCC, ExVideoHeader, ExAudioHeader)
│   ├── Extensions/              # UInt24, ByteBuffer helpers
│   ├── FLV/                     # FLV tags, header, codec probe
│   ├── Handshake/               # RTMP handshake (C0C1/S0S1S2/C2)
│   ├── Message/                 # RTMP messages, commands, control messages
│   ├── Metadata/                # StreamMetadata, cue points, captions
│   ├── Metrics/                 # Prometheus, StatsD export
│   ├── Monitoring/              # ConnectionMonitor, ConnectionStatistics
│   ├── MultiPublisher/          # Multi-destination fan-out publishing
│   ├── Probing/                 # Bandwidth probe, quality preset selection
│   ├── Publisher/               # RTMPPublisher, session, connection, stream key
│   ├── QualityScore/            # Connection quality scoring, grades, reports
│   ├── Recording/               # FLV recording, segmentation
│   ├── Server/                  # RTMP ingest server, relay, DVR, security
│   ├── Transport/               # NIOTransport, RTMPTransportProtocol, TLS
│   └── Documentation.docc/      # DocC articles
├── RTMPKitCommands/             # CLI commands (publish, record, probe, server, test-connection, info)
└── RTMPKitCLI/                  # CLI entry point (@main)
```

---

## Documentation

Full API documentation is available as a DocC catalog:

- **Online**: [atelier-socle.github.io/swift-rtmp-kit](https://atelier-socle.github.io/swift-rtmp-kit/documentation/rtmpkit/)
- **Xcode**: Open the project and select **Product > Build Documentation**

---

## Ecosystem

swift-rtmp-kit is part of the Atelier Socle streaming ecosystem:

- [PodcastFeedMaker](https://github.com/atelier-socle/podcast-feed-maker) — Podcast RSS feed generation
- [swift-hls-kit](https://github.com/atelier-socle/swift-hls-kit) — HTTP Live Streaming
- [swift-icecast-kit](https://github.com/atelier-socle/swift-icecast-kit) — Icecast/SHOUTcast streaming
- **swift-rtmp-kit** (this library) — RTMP streaming
- swift-srt-kit (coming soon) — SRT streaming

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).

Copyright 2026 [Atelier Socle SAS](https://www.atelier-socle.com). See [NOTICE](NOTICE) for details.
