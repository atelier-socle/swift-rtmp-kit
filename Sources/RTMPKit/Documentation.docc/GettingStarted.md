# Getting Started with RTMPKit

Set up your first RTMP live stream in minutes.

## Overview

RTMPKit provides everything you need to publish live audio and video to RTMP servers from Swift. This guide walks you through installation, basic configuration, and your first streaming session.

### Installation

Add RTMPKit to your `Package.swift`:

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

### Import

```swift
import RTMPKit
```

### Quick Start with Platform Preset

The fastest way to start streaming — use a platform preset:

```swift
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

Platform presets configure the server URL, TLS, chunk size, and Enhanced RTMP settings automatically. Available presets: Twitch, YouTube, Facebook, and Kick.

### Custom Server Configuration

For any RTMP server, create a configuration with a URL and stream key:

```swift
let config = RTMPConfiguration(
    url: "rtmp://live.example.com/app",
    streamKey: "my_stream_key"
)

let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)
```

You can customize all parameters:

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
```

### Error Handling

RTMPKit uses ``RTMPError`` for all failure cases:

```swift
do {
    try await publisher.publish(configuration: config)
} catch let error as RTMPError {
    switch error {
    case .connectionFailed(let reason):
        print("Connection failed: \(reason)")
    case .connectRejected(let code, let description):
        print("Server rejected: \(code) — \(description)")
    case .connectionTimeout:
        print("Connection timed out")
    default:
        print("Error: \(error.description)")
    }
}
```

## Next Steps

- <doc:StreamingGuide> — Complete streaming configuration and lifecycle
- <doc:PlatformPresetsGuide> — Twitch, YouTube, Facebook, and Kick presets
- <doc:EnhancedRTMPGuide> — HEVC, AV1, VP9, Opus via Enhanced RTMP v2
