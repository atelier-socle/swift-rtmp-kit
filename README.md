# swift-rtmp-kit

[![CI](https://github.com/atelier-socle/swift-rtmp-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/atelier-socle/swift-rtmp-kit/actions/workflows/ci.yml)
[![codecov](https://codecov.io/github/atelier-socle/swift-rtmp-kit/graph/badge.svg)](https://codecov.io/github/atelier-socle/swift-rtmp-kit)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS%20|%20Linux-blue.svg)]()
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

![swift-rtmp-kit](./assets/banner.png)

A pure Swift RTMP publish client for streaming live audio and video to RTMP and RTMPS ingest servers. Supports legacy codecs (H.264/AAC) and modern codecs via Enhanced RTMP v2 (HEVC, AV1, Opus). Built on SwiftNIO for high-performance TCP transport with NIOSSL for RTMPS. Platform presets for Twitch, YouTube Live, Facebook Live, and Kick. Strict `Sendable` conformance throughout. Cross-platform: macOS, iOS, tvOS, watchOS, visionOS, and Linux.

Part of the [Atelier Socle](https://www.atelier-socle.com) ecosystem.

---

## Features

- **RTMP/RTMPS Publish** — Connect and publish live streams to any RTMP-compatible ingest server
- **AMF0 Encoder/Decoder** — Full Action Message Format 0 implementation, pure Swift
- **Chunk Stream** — RTMP chunk stream multiplexing with configurable chunk sizes
- **Handshake** — Complete RTMP handshake (C0/C1/C2, S0/S1/S2)
- **FLV Tags** — Audio, video, and script data tag construction
- **Enhanced RTMP v2** — HEVC, AV1, and Opus codec support via enhanced headers
- **Platform Presets** — Pre-configured settings for Twitch, YouTube Live, Facebook Live, and Kick
- **Reconnection** — Automatic reconnection with exponential backoff
- **Monitoring** — Connection statistics, bitrate tracking, and health monitoring
- **CLI** — `rtmp-cli` command-line tool for publishing, testing connections, and inspecting servers

---

## Installation

### Requirements

- **Swift 6.2+** with strict concurrency
- **Library platforms**: macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1+
- **CLI platforms**: macOS 14+, Linux
- **Core dependencies**: SwiftNIO (TCP transport), NIOSSL (TLS for RTMPS)
- **CLI dependency**: `swift-argument-parser`

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/swift-rtmp-kit.git", from: "0.1.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["RTMPKit"]
)
```

### Homebrew

```bash
brew install atelier-socle/tools/swift-rtmp-kit
```

### Install Script

```bash
./Scripts/install.sh
# or with a custom prefix
PREFIX=~/.local/bin ./Scripts/install.sh
```

---

## Quick Start

```swift
import RTMPKit

// Connect to an RTMP server and publish a stream
let publisher = RTMPPublisher(
    url: "rtmp://live.twitch.tv/app",
    streamKey: "live_xxxxxxxxxxxx"
)

try await publisher.connect()
try await publisher.publish(streamName: "live")

// Send audio/video data
try await publisher.send(audioData: aacFrame)
try await publisher.send(videoData: h264Nalu)

// Disconnect
try await publisher.disconnect()
```

---

## Platform Presets

```swift
// Twitch — 6000 kbps, H.264/AAC
let twitch = RTMPPublisher(preset: .twitch(streamKey: "live_xxx"))

// YouTube Live — 4500 kbps, H.264/AAC
let youtube = RTMPPublisher(preset: .youtube(streamKey: "xxxx-xxxx-xxxx-xxxx"))

// Facebook Live — 4000 kbps, H.264/AAC
let facebook = RTMPPublisher(preset: .facebook(streamKey: "FB-xxx"))

// Kick — 6000 kbps, H.264/AAC
let kick = RTMPPublisher(preset: .kick(streamKey: "sk_xxx"))
```

---

## CLI

### Usage

```bash
# Publish a stream
rtmp-cli publish rtmp://live.twitch.tv/app --stream-key live_xxx --input camera

# Test connection to an RTMP server
rtmp-cli test-connection rtmp://live.twitch.tv/app

# Show server info
rtmp-cli info rtmp://live.twitch.tv/app
```

### Commands

| Command | Description |
|---------|-------------|
| `publish` | Publish a live stream to an RTMP/RTMPS server |
| `test-connection` | Test connectivity and handshake with an RTMP server |
| `info` | Display server information and capabilities |

---

## HLSKit Bridge

If you use [swift-hls-kit](https://github.com/atelier-socle/swift-hls-kit) for HLS output, you can bridge RTMP input to HLS in your consuming app:

```swift
import RTMPKit
import HLSKit

// Receive RTMP → segment → push HLS
let publisher = RTMPPublisher(url: "rtmp://ingest.example.com/live", streamKey: "key")
try await publisher.connect()

for await frame in publisher.videoFrames {
    // Feed frames into HLSKit's live segmenter
    try await segmenter.ingest(frame)
}
```

---

## Architecture

```
Sources/
├── RTMPKit/                     # Core library (NIO transport)
│   ├── Protocol/                # RTMP protocol types, message IDs
│   ├── Handshake/               # C0/C1/C2, S0/S1/S2 handshake
│   ├── Chunk/                   # Chunk stream, chunk header, de/mux
│   ├── AMF/                     # AMF0 encoder/decoder
│   ├── FLV/                     # FLV tag builder (audio, video, script)
│   ├── Enhanced/                # Enhanced RTMP v2 (HEVC, AV1, Opus)
│   ├── Transport/               # NIO channel handlers, TLS
│   ├── Publisher/               # RTMPPublisher, connection state
│   ├── Presets/                 # Platform presets (Twitch, YouTube, etc.)
│   ├── Monitor/                 # Connection statistics, health
│   └── Documentation.docc/      # DocC articles
├── RTMPKitCommands/             # CLI command implementations
└── RTMPKitCLI/                  # CLI entry point
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).

Copyright 2026 [Atelier Socle SAS](https://www.atelier-socle.com). See [NOTICE](NOTICE) for details.
