# Enhanced RTMP Guide

Use Enhanced RTMP v2 for modern codecs like HEVC, AV1, VP9, and Opus.

@Metadata {
    @PageKind(article)
}

## Overview

Enhanced RTMP v2 extends the original RTMP specification with FourCC-based codec negotiation, allowing modern codecs beyond the legacy H.264/AAC pair. RTMPKit implements the full Enhanced RTMP v2 specification including codec negotiation, extended audio/video headers, and multitrack stubs.

### What is Enhanced RTMP

The original RTMP specification only supports a limited set of codecs identified by numeric IDs (e.g., 7 for H.264, 10 for AAC). Enhanced RTMP v2 introduces four-character codes (FourCC) to identify codecs, enabling support for modern formats like HEVC, AV1, VP9, and Opus without breaking backward compatibility.

### Supported Codecs

RTMPKit supports all 8 FourCC constants defined in the Enhanced RTMP specification:

| FourCC | Codec | Type | String Value |
|--------|-------|------|-------------|
| ``FourCC/hevc`` | HEVC (H.265) | Video | `hvc1` |
| ``FourCC/av1`` | AV1 | Video | `av01` |
| ``FourCC/vp9`` | VP9 | Video | `vp09` |
| ``FourCC/opus`` | Opus | Audio | `Opus` |
| ``FourCC/flac`` | FLAC | Audio | `fLaC` |
| ``FourCC/ac3`` | AC-3 | Audio | `ac-3` |
| ``FourCC/eac3`` | E-AC-3 | Audio | `ec-3` |
| ``FourCC/mp4a`` | AAC (MP4A) | Audio | `mp4a` |

```swift
// Video codec detection
FourCC.hevc.isVideoCodec  // true
FourCC.av1.isVideoCodec   // true
FourCC.opus.isVideoCodec  // false

// Audio codec detection
FourCC.opus.isAudioCodec  // true
FourCC.flac.isAudioCodec  // true
FourCC.hevc.isAudioCodec  // false
```

### How Negotiation Works

When Enhanced RTMP is enabled, the client sends a `fourCcList` property in the RTMP connect command. The server echoes back the codecs it supports. The negotiated codecs are then available on ``RTMPPublisher/serverInfo``.

1. **Client sends connect** — includes `fourCcList` as an AMF0 strict array of FourCC values
2. **Server responds with `_result`** — echoes the `fourCcList` of codecs it supports
3. **Client uses negotiated codecs** — sends enhanced audio/video tags with FourCC headers

```swift
// Build the fourCcList for the connect command
let codecs: [FourCC] = [.hevc, .av1, .vp9, .opus]
let fourCcAMF = EnhancedRTMP.fourCcListAMF0(codecs: codecs)

// Parse the server's response
let serverResponse: AMF0Value = // ... from _result
let negotiated = EnhancedRTMP.parseFourCcList(from: serverResponse)
// negotiated == [.hevc, .av1] (only what the server supports)
```

### Using Enhanced RTMP

Enhanced RTMP is enabled by default when creating an ``RTMPConfiguration``. Platform presets configure it automatically — Twitch and YouTube support Enhanced RTMP, while Facebook and Kick do not.

```swift
// Enhanced RTMP is on by default
let config = RTMPConfiguration(
    url: "rtmp://server/app",
    streamKey: "key"
)
// config.enhancedRTMP == true

// Platform presets set it automatically
let twitch = RTMPConfiguration.twitch(streamKey: "key")
// twitch.enhancedRTMP == true (Twitch supports it)

let facebook = RTMPConfiguration.facebook(streamKey: "key")
// facebook.enhancedRTMP == false (Facebook does not)
```

After connecting, check which codecs were negotiated:

```swift
let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)

let info = await publisher.serverInfo
if info.enhancedRTMP {
    let codecs = info.negotiatedCodecs.map(\.stringValue)
    print("Enhanced RTMP codecs: \(codecs.joined(separator: ", "))")
}
```

### HEVC Video Tags

Build Enhanced RTMP video tags for HEVC using ``FLVVideoTag``:

```swift
// Sequence header (decoder configuration)
let seqHeader = FLVVideoTag.enhancedSequenceStart(
    fourCC: .hevc, config: hevcDecoderConfig
)

// Coded frames with composition time offset
let codedFrame = FLVVideoTag.enhancedCodedFrames(
    fourCC: .hevc, data: naluData, isKeyframe: true, cts: 33
)

// AV1 uses CodedFramesX (no CTS)
let av1Frame = FLVVideoTag.enhancedCodedFramesX(
    fourCC: .av1, data: obuData, isKeyframe: true
)

// End of sequence
let endSeq = FLVVideoTag.enhancedSequenceEnd(fourCC: .hevc)
```

### Opus Audio Tags

Build Enhanced RTMP audio tags for Opus using ``FLVAudioTag``:

```swift
// Sequence header (Opus configuration)
let seqStart = FLVAudioTag.enhancedSequenceStart(
    fourCC: .opus, config: opusConfig
)

// Coded frame
let frame = FLVAudioTag.enhancedCodedFrame(
    fourCC: .opus, data: opusData
)

// End of sequence
let endSeq = FLVAudioTag.enhancedSequenceEnd(fourCC: .opus)
```

### Disabling Enhanced RTMP

Disable Enhanced RTMP if the server does not support it or you want to force legacy FLV tags:

```swift
// In code
let config = RTMPConfiguration(
    url: "rtmp://server/app",
    streamKey: "key",
    enhancedRTMP: false
)

// Via CLI
// rtmp-cli publish --url rtmp://server/app --key xxx --file video.flv --no-enhanced-rtmp
```

### Fallback to Legacy

When a server does not support Enhanced RTMP, the `fourCcList` in the response will be empty. RTMPKit falls back to legacy FLV tags automatically:

```swift
let enhanced = EnhancedRTMP(isEnabled: true, negotiatedCodecs: [])
enhanced.supports(.hevc)  // false — use legacy tags instead

// Legacy video tags still work
let legacyVideo = FLVVideoTag.avcNALU(naluData, isKeyframe: true)
```

### Multitrack Support

RTMPKit includes stub types for the Enhanced RTMP multitrack extension. ``MultitrackType`` defines three modes for future multi-track audio/video support:

| Type | Description |
|------|-------------|
| `.oneTrack` | Single track (default) |
| `.manyTracks` | Multiple tracks, same codec |
| `.manyTracksManyCodecs` | Multiple tracks, different codecs |

## Next Steps

- <doc:StreamingGuide> — Complete streaming configuration and lifecycle
- <doc:PlatformPresetsGuide> — Which platforms support Enhanced RTMP
- <doc:GettingStarted> — Basic setup and quick start
