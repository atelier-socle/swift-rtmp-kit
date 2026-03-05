# Metadata Guide

Send dynamic stream metadata, cue points, and captions during live streaming.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit supports dynamic metadata updates during streaming using the RTMP `@setDataFrame` / `onMetaData` mechanism. You can send stream information (resolution, bitrate, codec IDs), timed cue points, and captions.

### Stream Metadata

``StreamMetadata`` holds standard RTMP metadata fields. Use factory methods for common configurations:

```swift
// H.264 + AAC metadata (1080p30, 4.5 Mbps video, 128 Kbps audio)
let meta = StreamMetadata.h264AAC(
    width: 1920, height: 1080, frameRate: 30,
    videoBitrate: 4_500_000, audioBitrate: 128_000
)
// meta.videoCodecID == 7.0 (H.264)
// meta.audioCodecID == 10.0 (AAC)

// HEVC + AAC metadata (4K60, 20 Mbps video)
let hevcMeta = StreamMetadata.hevcAAC(
    width: 3840, height: 2160, frameRate: 60,
    videoBitrate: 20_000_000, audioBitrate: 256_000
)
// hevcMeta.videoCodecID == 12.0 (HEVC)
// hevcMeta.audioSampleRate == 48000

// Audio-only metadata
let audioMeta = StreamMetadata.audioOnly(
    codecID: 10.0, bitrate: 320_000,
    sampleRate: 48000, channels: 1
)
// audioMeta.width == nil (no video)
// audioMeta.audioChannels == 1
```

### AMF0 Roundtrip

``StreamMetadata`` supports full AMF0 encoding and decoding:

```swift
let meta = StreamMetadata.h264AAC(
    width: 1920, height: 1080, frameRate: 30,
    videoBitrate: 4_500_000, audioBitrate: 128_000
)

// Encode to AMF0 and decode back
let amf0 = meta.toAMF0()
let roundtripped = StreamMetadata.fromAMF0(amf0)
// roundtripped.width == 1920
// roundtripped.videoCodecID == 7.0
// roundtripped.videoBitrate == 4_500_000
```

### Sending Metadata

Set initial metadata on the configuration, or update it during streaming:

```swift
// Initial metadata — sent automatically on publish
var config = RTMPConfiguration.twitch(streamKey: "live_xxx")
config.initialMetadata = StreamMetadata.h264AAC(
    width: 1920, height: 1080, frameRate: 30,
    videoBitrate: 3_000_000, audioBitrate: 128_000
)
// config.initialMetadata?.width == 1920

// Update metadata during streaming
try await publisher.updateStreamInfo(updatedMeta)
```

### Timed Metadata

``TimedMetadata`` supports text data, cue points, and captions. Each type is encoded as a distinct RTMP data message:

| Type | RTMP Command | Description |
|------|-------------|-------------|
| `.text(String, timestamp:)` | `onTextData` | Timed text overlay |
| `.cuePoint(CuePoint)` | `onCuePoint` | Navigation or event marker |
| `.caption(CaptionData)` | `onCaptionInfo` | Closed caption data |

```swift
// Send timed metadata through the publisher
try await publisher.send(.text("hello", timestamp: 0))
try await publisher.send(.cuePoint(CuePoint(name: "ch1", time: 1000)))
try await publisher.send(.caption(CaptionData(text: "sub", timestamp: 2000)))
```

### Cue Points

``CuePoint`` supports navigation and event markers with rich parameters:

```swift
let cuePoint = CuePoint(
    name: "ad-break",
    time: 30000,
    type: .event,
    parameters: [
        "duration": .number(15),
        "sponsor": .string("acme"),
        "skippable": .boolean(true)
    ]
)

// Encode to AMF0 object
let amf0 = cuePoint.toAMF0Object()
// Properties: name, time, type, duration, sponsor, skippable
```

### Captions

``CaptionData`` supports multiple caption standards:

```swift
// All caption standards
for standard in CaptionData.CaptionStandard.allCases {
    let caption = CaptionData(
        standard: standard, text: "test",
        language: "en", timestamp: 0
    )
    let amf0 = caption.toAMF0Object()
    // Each standard encodes correctly
}
```

### Custom Fields

``StreamMetadata`` supports custom fields for platform-specific extensions:

```swift
var meta = StreamMetadata()
meta.width = 1920
meta.customFields["copyright"] = .string("2026 Acme")
meta.customFields["rating"] = .number(5)

// Custom fields survive AMF0 roundtrip
let amf0 = meta.toAMF0()
let entries = amf0.ecmaArrayEntries!
// Contains "copyright", "rating", and "width"
```

### MetadataUpdater Pipeline

``MetadataUpdater`` handles encoding and sending metadata through a send closure:

```swift
let updater = MetadataUpdater { bytes in
    // bytes contain AMF0-encoded payload
    // First value: "@setDataFrame" or "onTextData" etc.
}

// Send stream info → encodes as @setDataFrame + onMetaData
try await updater.updateStreamInfo(meta)

// Send timed metadata
try await updater.sendText("hello", timestamp: 0)
try await updater.sendCuePoint(CuePoint(name: "ch1", time: 1000))
try await updater.sendCaption(CaptionData(text: "sub", timestamp: 2000))
```

### Multi-Destination Metadata

``MultiPublisher`` forwards metadata to all active destinations:

```swift
await multi.sendMetadata(streamMeta)
await multi.sendText("Now playing: Song Title", timestamp: 10.0)
await multi.sendCuePoint(cuePoint)
await multi.sendCaption(captionData)
```

## Next Steps

- <doc:StreamingGuide> — Complete streaming lifecycle
- <doc:EnhancedRTMPGuide> — Codec metadata for Enhanced RTMP
- <doc:RecordingGuide> — Recording metadata in FLV files
