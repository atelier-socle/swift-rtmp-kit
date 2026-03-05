# FLV Codec Probe Guide

Auto-detect video and audio codecs in FLV files and enable Enhanced RTMP v2 transparently.

@Metadata {
    @PageKind(article)
}

## Overview

``FLVCodecProbe`` scans the first few tags of an FLV file to identify the video and audio codecs. When a non-H.264 codec is detected (HEVC, AV1, VP9), the CLI automatically enables Enhanced RTMP v2 and sends the `fourCcList` in the RTMP connect command.

### Probing Codecs

```swift
let codecInfo = FLVCodecProbe.probe(data: flvBytes, dataOffset: 13)
print("Video: \(codecInfo.videoCodec.displayName)")
print("Audio: \(codecInfo.audioCodec.displayName)")
```

### Supported Codecs

**Video codecs (``FLVVideoCodec``):**

| Codec | Detection | Enhanced RTMP |
|-------|-----------|---------------|
| `.h264` | Legacy codec ID 7 | Not required |
| `.hevc` | FourCC `hvc1` | Required |
| `.av1` | FourCC `av01` | Required |
| `.vp9` | FourCC `vp09` | Required |
| `.unknown` | Unrecognized | Not required |

**Audio codecs (``FLVAudioCodec``):**

| Codec | Detection | Enhanced RTMP |
|-------|-----------|---------------|
| `.aac` | SoundFormat 10 | Not required |
| `.opus` | FourCC `Opus` | Required |
| `.unknown` | Unrecognized | Not required |

### Enhanced RTMP Auto-Enable

The ``FLVVideoCodec/requiresEnhancedRTMP`` property determines whether Enhanced RTMP v2 is needed:

```swift
let codecInfo = FLVCodecProbe.probe(data: flvBytes, dataOffset: 13)

if codecInfo.videoCodec.requiresEnhancedRTMP {
    // HEVC, AV1, or VP9 — fourCcList will be sent in connect command
    print("\(codecInfo.videoCodec.displayName) — Enhanced RTMP v2 will be used")
}
```

### CLI Auto-Detection

The CLI automatically probes FLV files before publishing:

```bash
# HEVC FLV → Enhanced RTMP v2 enabled automatically
rtmp-cli publish --url rtmp://server/app --key key --file hevc_stream.flv
# Output:
# Video: HEVC (H.265) — Enhanced RTMP v2 will be used
# Audio: AAC

# H.264 FLV → legacy RTMP (no fourCcList)
rtmp-cli publish --url rtmp://server/app --key key --file h264_stream.flv
# Output:
# Video: H.264
# Audio: AAC

# Force legacy mode (not recommended for HEVC/AV1/VP9)
rtmp-cli publish --url rtmp://server/app --key key --file hevc_stream.flv \
  --no-enhanced-rtmp
```

### Display Names

Both ``FLVVideoCodec/displayName`` and ``FLVAudioCodec/displayName`` provide human-readable strings for CLI output and logging:

| Codec | Display Name |
|-------|-------------|
| `.h264` | H.264 |
| `.hevc` | HEVC (H.265) |
| `.av1` | AV1 |
| `.vp9` | VP9 |
| `.aac` | AAC |
| `.opus` | Opus |

## Next Steps

- <doc:EnhancedRTMPGuide> — Enhanced RTMP v2 codec negotiation
- <doc:StreamingGuide> — Complete streaming lifecycle
- <doc:CLIReference> — CLI publish command reference
