# Streaming Guide

Configure connections, manage the publish lifecycle, and stream audio and video data.

@Metadata {
    @PageKind(article)
}

## Overview

This guide covers the complete streaming workflow: configuring the server connection, managing the RTMP publish lifecycle, sending audio and video frames, setting stream metadata, and disconnecting gracefully. All code examples are verified against the actual RTMPKit API.

### Configuration

``RTMPConfiguration`` holds all parameters for connecting to an RTMP server:

```swift
let config = RTMPConfiguration(
    url: "rtmp://live.example.com/app",
    streamKey: "my_stream_key",
    chunkSize: 4096,
    enhancedRTMP: true,
    reconnectPolicy: .default,
    flashVersion: "FMLE/3.0 (compatible; FMSc/1.0)",
    transportConfiguration: .default
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `url` | `String` | (required) | RTMP server URL without stream key |
| `streamKey` | `String` | (required) | Stream key (not logged for security) |
| `chunkSize` | `UInt32` | `4096` | RTMP chunk size to negotiate |
| `enhancedRTMP` | `Bool` | `true` | Negotiate Enhanced RTMP v2 |
| `reconnectPolicy` | ``ReconnectPolicy`` | `.default` | Auto-reconnection strategy |
| `flashVersion` | `String` | `"FMLE/3.0 ..."` | Flash version for connect command |
| `transportConfiguration` | ``TransportConfiguration`` | `.default` | TCP/TLS transport settings |

### Connection Lifecycle

``RTMPPublisher`` follows a state machine managed by ``RTMPPublisherState``:

```
idle --> connecting --> handshaking --> connected --> publishing
 ^                                                      |
 <----------- reconnecting(attempt:) <-----------------+
 ^                                                      |
 <----------- failed(error) <--------------------------+
 ^                                                      |
 <----------- disconnected <----------------------------+
```

**States:**

| State | Description |
|-------|-------------|
| `.idle` | Not connected |
| `.connecting` | TCP connection in progress |
| `.handshaking` | RTMP handshake (C0C1/S0S1S2/C2) in progress |
| `.connected` | RTMP connect + createStream succeeded |
| `.publishing` | Actively publishing (publish command accepted) |
| `.reconnecting(attempt:)` | Reconnecting after connection loss |
| `.failed(_)` | Connection failed with ``RTMPError`` |
| `.disconnected` | Gracefully disconnected |

```swift
let publisher = RTMPPublisher()
// state == .idle

try await publisher.publish(configuration: config)
// state == .publishing

await publisher.disconnect()
// state == .disconnected
```

### Sending Audio

Send AAC audio with a sequence header followed by raw frames:

```swift
// Send AAC decoder configuration first (AudioSpecificConfig)
try await publisher.sendAudioConfig(aacSequenceHeader)

// Then send AAC raw frames with timestamps
try await publisher.sendAudio(aacFrame, timestamp: 0)
try await publisher.sendAudio(aacFrame2, timestamp: 23)
try await publisher.sendAudio(aacFrame3, timestamp: 46)
```

The ``RTMPPublisher/sendAudioConfig(_:)`` method wraps the data in an FLV AAC sequence header tag. The ``RTMPPublisher/sendAudio(_:timestamp:)`` method wraps data in an FLV AAC raw frame tag. Timestamps are in milliseconds.

### Sending Video

Send H.264 video with a sequence header followed by NAL units:

```swift
// Send AVC decoder configuration first (AVCDecoderConfigurationRecord)
try await publisher.sendVideoConfig(avcSequenceHeader)

// Then send video frames with timestamps and keyframe flag
try await publisher.sendVideo(naluData, timestamp: 0, isKeyframe: true)
try await publisher.sendVideo(naluData2, timestamp: 33, isKeyframe: false)
try await publisher.sendVideo(naluData3, timestamp: 66, isKeyframe: false)
```

The ``RTMPPublisher/sendVideoConfig(_:)`` method wraps the data in an FLV AVC sequence header tag. The ``RTMPPublisher/sendVideo(_:timestamp:isKeyframe:)`` method wraps data in an FLV AVC NALU tag.

### Stream Metadata

Send `@setDataFrame` metadata with stream properties using ``StreamMetadata``:

```swift
var metadata = StreamMetadata()
metadata.width = 1920
metadata.height = 1080
metadata.videoDataRate = 5000
metadata.frameRate = 30
metadata.videoCodecID = 7  // AVC
metadata.audioDataRate = 128
metadata.audioSampleRate = 44100
metadata.audioSampleSize = 16
metadata.isStereo = true
metadata.audioCodecID = 10  // AAC
metadata.encoder = "RTMPKit/0.2.0"

try await publisher.updateMetadata(metadata)
```

### Graceful Disconnect

``RTMPPublisher/disconnect()`` performs a proper RTMP teardown sequence: FCUnpublish, deleteStream, then closes the TCP connection. It is safe to call in any state (idempotent):

```swift
await publisher.disconnect()
// state == .disconnected
```

### Error Handling

``RTMPError`` covers all failure modes across the RTMP lifecycle:

```swift
do {
    try await publisher.publish(configuration: config)
    try await publisher.sendVideo(data, timestamp: 0, isKeyframe: true)
} catch let error as RTMPError {
    switch error {
    case .connectionFailed(let reason):
        print("Connection failed: \(reason)")
    case .handshakeFailed(let reason):
        print("Handshake failed: \(reason)")
    case .connectRejected(let code, let description):
        print("Connect rejected: \(code) — \(description)")
    case .publishFailed(let code, let description):
        print("Publish rejected: \(code) — \(description)")
    case .notPublishing:
        print("Cannot send media — not publishing")
    default:
        print("RTMP error: \(error.description)")
    }
}
```

### Event Monitoring

Subscribe to the ``RTMPPublisher/events`` `AsyncStream` to observe state changes, server messages, and errors:

```swift
let eventTask = Task {
    for await event in publisher.events {
        switch event {
        case .stateChanged(let state):
            print("State: \(state)")
        case .serverMessage(let code, let description):
            print("Server: \(code) — \(description)")
        case .acknowledgementReceived(let seqNum):
            print("Ack: \(seqNum)")
        case .pingReceived:
            print("Ping received")
        case .error(let error):
            print("Error: \(error)")
        case .statisticsUpdate(let stats):
            print("Stats: \(stats.bytesSent) bytes sent")
        }
    }
}
```

## Next Steps

- <doc:EnhancedRTMPGuide> — HEVC, AV1, Opus via Enhanced RTMP v2
- <doc:PlatformPresetsGuide> — Platform-specific configuration
- <doc:ReconnectionGuide> — Auto-reconnect configuration
