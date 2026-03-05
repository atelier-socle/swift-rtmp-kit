# ``RTMPKit``

@Metadata {
    @DisplayName("RTMPKit")
}

Pure Swift RTMP publish client for live streaming to Twitch, YouTube, Facebook, Kick, and any RTMP server.

## Overview

RTMPKit provides a complete, production-ready RTMP publish client for live audio and video streaming. The library handles the full RTMP lifecycle — handshake, chunking, AMF0/AMF3 encoding, FLV packaging, Enhanced RTMP v2 codec negotiation, and graceful teardown — all built with Swift 6.2 strict concurrency and zero external dependencies on the core target.

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
- **Enhanced RTMP v2** — FourCC codec negotiation for HEVC, AV1, VP9, Opus, FLAC, AC-3, E-AC-3 with auto-detection from FLV files
- **FLV packaging** — Audio tags (AAC), video tags (H.264), script data, and sequence headers
- **Platform presets** — One-line configuration for Twitch, YouTube, Facebook, Kick, Instagram, TikTok, and more
- **Adaptive bitrate** — Conservative, responsive, and aggressive ABR policies with frame dropping
- **Multi-destination publishing** — Stream simultaneously to multiple servers with per-destination state and failure isolation
- **RTMP authentication** — Simple (query string), token, and Adobe MD5 challenge/response
- **Stream recording** — Record live streams to FLV with segmentation and size limits
- **Bandwidth probing** — Measure available bandwidth and get quality preset recommendations
- **Connection quality scoring** — Composite quality grades with warning thresholds
- **Dynamic metadata** — Update `@setDataFrame`/`onMetaData` during streaming, cue points, and captions
- **AMF3 support** — Full AMF3 encoding and decoding for all 18 type markers
- **Prometheus and StatsD metrics** — Export streaming metrics to monitoring systems
- **RTMP server** — Ingest server with stream key validation, relay, and DVR
- **Auto-reconnect** — Exponential backoff with configurable jitter and retry policies
- **Real-time monitoring** — Connection statistics, bitrate tracking, dropped frame detection, RTT measurement
- **Transport DI** — Dependency injection for testing without a real RTMP server
- **CLI tool** — `rtmp-cli` for streaming, recording, probing, and server management
- **Cross-platform** — macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1+, Linux (Swift 6.2+)
- **Swift 6.2 strict concurrency** — Actors, `Sendable`, `async`/`await` throughout, zero `@unchecked Sendable`

### Standards

| Standard | Reference |
|----------|-----------|
| RTMP 1.0 | [Adobe RTMP Specification (PDF)](https://veovera.github.io/enhanced-rtmp/docs/legacy/rtmp-v1-0-spec.pdf) |
| Enhanced RTMP v2 | [Veovera Enhanced RTMP (GitHub)](https://github.com/veovera/enhanced-rtmp) |
| AMF0 | [Adobe AMF0 Specification (PDF)](https://veovera.github.io/enhanced-rtmp/docs/legacy/amf0-file-format-spec.pdf) |
| AMF3 | [Adobe AMF3 Specification (PDF)](https://veovera.github.io/enhanced-rtmp/docs/legacy/amf3-file-format-spec.pdf) |
| FLV File Format | [Adobe FLV/F4V Specification v10.1 (PDF)](https://veovera.github.io/enhanced-rtmp/docs/legacy/video-file-format-v10-1-spec.pdf) |

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:StreamingGuide>
- <doc:CLIReference>

### Streaming Features

- <doc:AdaptiveBitrateGuide>
- <doc:MultiDestinationGuide>
- <doc:RecordingGuide>
- <doc:MetadataGuide>
- <doc:FLVCodecProbeGuide>

### Authentication

- <doc:AuthenticationGuide>

### Configuration

- <doc:PlatformPresetsGuide>
- <doc:ReconnectionGuide>
- <doc:BandwidthProbeGuide>

### Monitoring and Metrics

- <doc:MonitoringGuide>
- <doc:QualityScoreGuide>
- <doc:MetricsExportGuide>

### Protocol and Encoding

- <doc:EnhancedRTMPGuide>
- <doc:AMF3Guide>

### Testing

- <doc:TransportDIGuide>
- <doc:TestingGuide>

### Core Publisher

- ``RTMPPublisher``
- ``RTMPConfiguration``
- ``RTMPPublisherState``
- ``RTMPError``
- ``RTMPEvent``

### Multi-Destination

- ``MultiPublisher``
- ``PublishDestination``
- ``DestinationState``
- ``MultiPublisherEvent``
- ``MultiPublisherFailurePolicy``
- ``MultiPublisherStatistics``

### Adaptive Bitrate

- ``AdaptiveBitratePolicy``
- ``AdaptiveBitrateConfiguration``
- ``NetworkConditionMonitor``
- ``BitrateRecommendation``
- ``BitrateChangeReason``
- ``FrameDroppingStrategy``

### Authentication Types

- ``RTMPAuthentication``
- ``AdobeChallengeAuth``
- ``SimpleAuth``
- ``TokenAuth``

### Configuration Types

- ``PlatformPreset``
- ``ReconnectPolicy``
- ``TwitchIngestServer``
- ``TransportConfiguration``
- ``ObjectEncoding``
- ``StreamingPlatformRegistry``

### Monitoring Types

- ``ConnectionMonitor``
- ``ConnectionStatistics``
- ``RTMPStatusCode``
- ``StatusInfo``
- ``ServerInfo``

### Quality Scoring

- ``ConnectionQualityScore``
- ``ConnectionQualityMonitor``
- ``QualityDimension``
- ``QualityReport``

### Bandwidth Probing

- ``BandwidthProbe``
- ``ProbeConfiguration``
- ``ProbeResult``
- ``QualityPresetSelector``

### FLV and Codec Types

- ``FLVCodecProbe``
- ``FLVCodecInfo``
- ``FLVVideoCodec``
- ``FLVAudioCodec``
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

### Protocol Types

- ``AMF0Value``
- ``AMF0Encoder``
- ``AMF0Decoder``
- ``AMF3Value``
- ``AMF3Encoder``
- ``AMF3Decoder``
- ``AMF3Traits``
- ``AMF3Object``
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

### Recording

- ``StreamRecorder``
- ``RecordingConfiguration``
- ``RecordingSegment``
- ``RecordingEvent``
- ``FLVWriter``
- ``ElementaryStreamWriter``

### Metadata

- ``TimedMetadata``
- ``MetadataUpdater``
- ``CuePoint``
- ``CaptionData``

### Metrics Export

- ``RTMPMetricsExporter``
- ``RTMPPublisherStatistics``
- ``PrometheusExporter``
- ``StatsDExporter``

### Server

- ``RTMPServer``
- ``RTMPServerConfiguration``
- ``RTMPServerSession``
- ``RTMPServerEvent``
- ``RTMPServerSessionDelegate``
- ``RTMPServerSecurityPolicy``
- ``StreamKeyValidator``
- ``AllowListStreamKeyValidator``
- ``ClosureStreamKeyValidator``
- ``RTMPStreamRelay``
- ``RTMPStreamDVR``
- ``RTMPConnectionRateLimiter``
- ``RTMPServerAccessControl``

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
- ``AMF3EncodingError``
- ``AMF3DecodingError``
- ``ChunkError``
- ``FLVError``
