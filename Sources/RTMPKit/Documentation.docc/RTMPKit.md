# ``RTMPKit``

@Metadata {
    @DisplayName("RTMPKit")
}

Pure Swift RTMP publish client for live streaming to Twitch, YouTube, Facebook, Kick, and any RTMP server.

## Overview

RTMPKit provides a complete, production-ready RTMP publish client for live audio and video streaming. The library handles the full RTMP lifecycle — handshake, chunking, AMF0 encoding, FLV packaging, Enhanced RTMP v2 codec negotiation, and graceful teardown — all built with Swift 6.2 strict concurrency and zero external dependencies on the core target.

```swift
import RTMPKit

let config = RTMPConfiguration.twitch(streamKey: "live_xxx")
let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)

try await publisher.sendAudioConfig(aacSequenceHeader)
try await publisher.sendVideoConfig(avcSequenceHeader)
try await publisher.sendAudio(aacFrame, timestamp: 0)
try await publisher.sendVideo(naluData, timestamp: 0, isKeyframe: true)

await publisher.disconnect()
```

### Key Features

- **RTMP 1.0** — Full protocol implementation: handshake, chunk stream multiplexing, AMF0 commands
- **Enhanced RTMP v2** — FourCC codec negotiation for HEVC, AV1, VP9, Opus, FLAC, AC-3, E-AC-3
- **FLV packaging** — Audio tags (AAC), video tags (H.264), script data, and sequence headers
- **Platform presets** — One-line configuration for Twitch, YouTube, Facebook, and Kick
- **Auto-reconnect** — Exponential backoff with configurable jitter and retry policies
- **Real-time monitoring** — Connection statistics, bitrate tracking, dropped frame detection, RTT measurement
- **Transport DI** — Dependency injection for testing without a real RTMP server
- **Cross-platform** — macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1+, Linux (Swift 6.2+)
- **CLI tool** — `rtmp-cli` for streaming FLV files, testing connections, and querying server info
- **Swift 6.2 strict concurrency** — Actors, `Sendable`, `async`/`await` throughout, zero `@unchecked Sendable`

### Standards

| Standard | Reference |
|----------|-----------|
| RTMP 1.0 | [Adobe RTMP Specification](https://rtmp.veriskope.com/docs/spec/) |
| Enhanced RTMP v2 | [Veritone Enhanced RTMP](https://rtmp.veriskope.com/docs/enhanced/) |
| AMF0 | [Adobe AMF0 Specification](https://rtmp.veriskope.com/docs/amf0-spec/) |
| FLV File Format | [Adobe FLV and F4V](https://rtmp.veriskope.com/docs/legacy/flv-spec/) |

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:StreamingGuide>

### Protocol

- <doc:EnhancedRTMPGuide>

### Configuration

- <doc:PlatformPresetsGuide>
- <doc:ReconnectionGuide>

### Monitoring

- <doc:MonitoringGuide>

### Testing

- <doc:TransportDIGuide>
- <doc:TestingGuide>

### Tools

- <doc:CLIReference>

### Publisher

- ``RTMPPublisher``
- ``RTMPConfiguration``
- ``RTMPPublisherState``
- ``RTMPError``

### Protocol Types

- ``AMF0Value``
- ``AMF0Encoder``
- ``AMF0Decoder``
- ``ChunkHeader``
- ``ChunkAssembler``
- ``ChunkDisassembler``
- ``RTMPHandshake``
- ``HandshakeBytes``
- ``HandshakeValidator``

### Message Types

- ``RTMPMessage``
- ``RTMPCommand``
- ``RTMPControlMessage``
- ``RTMPDataMessage``
- ``RTMPUserControlEvent``
- ``ConnectProperties``
- ``StreamMetadata``

### FLV Types

- ``FLVHeader``
- ``FLVAudioTag``
- ``FLVVideoTag``
- ``FLVScriptTag``
- ``FLVTagType``

### Enhanced RTMP Types

- ``FourCC``
- ``EnhancedRTMP``
- ``ExVideoHeader``
- ``ExVideoPacketType``
- ``VideoFrameType``
- ``ExAudioHeader``
- ``ExAudioPacketType``
- ``MultitrackType``

### Configuration Types

- ``PlatformPreset``
- ``ReconnectPolicy``
- ``TwitchIngestServer``
- ``TransportConfiguration``

### Monitoring Types

- ``ConnectionMonitor``
- ``ConnectionStatistics``
- ``RTMPStatusCode``
- ``RTMPEvent``
- ``StatusInfo``
- ``ServerInfo``

### Transport

- ``RTMPTransportProtocol``
- ``NIOTransport``
- ``TransportError``

### Connection

- ``RTMPConnection``
- ``RTMPSession``
- ``StreamKey``

### Errors

- ``AMF0Error``
- ``ChunkError``
- ``FLVError``
