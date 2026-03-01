# Platform Presets Guide

Configure streaming for Twitch, YouTube, Facebook, Kick, and custom RTMP servers.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit provides one-line platform presets that configure the server URL, TLS, chunk size, Enhanced RTMP, and flash version for major streaming platforms. Use presets for quick setup, or build a custom ``RTMPConfiguration`` for any RTMP server.

### Twitch

``RTMPConfiguration/twitch(streamKey:ingestServer:useTLS:)`` creates a configuration for Twitch with RTMPS, Enhanced RTMP enabled, and automatic ingest server selection:

```swift
// Default: auto ingest server, RTMPS
let config = RTMPConfiguration.twitch(streamKey: "live_abc123")
// config.url starts with "rtmps://" and contains "twitch.tv"
// config.enhancedRTMP == true
// config.chunkSize == 4096

// Specific ingest server
let euConfig = RTMPConfiguration.twitch(
    streamKey: "live_eu_key",
    ingestServer: .europe
)
```

Available ingest servers via ``TwitchIngestServer``:

| Server | Description |
|--------|-------------|
| `.auto` | Automatic selection (default) |
| `.usEast` | US East |
| `.usWest` | US West |
| `.europe` | Europe |
| `.asia` | Asia |
| `.southAmerica` | South America |
| `.australia` | Australia |

### YouTube

``RTMPConfiguration/youtube(streamKey:ingestURL:)`` creates a configuration for YouTube Live with RTMPS and Enhanced RTMP:

```swift
// Default YouTube ingest
let config = RTMPConfiguration.youtube(streamKey: "xxxx-xxxx-xxxx-xxxx")
// config.url contains "youtube.com"
// config.enhancedRTMP == true

// Custom ingest URL (from YouTube API)
let custom = RTMPConfiguration.youtube(
    streamKey: "yt-key",
    ingestURL: "rtmps://custom.youtube.com/live2"
)
```

### Facebook

``RTMPConfiguration/facebook(streamKey:)`` creates a configuration for Facebook Live. Facebook does **not** support Enhanced RTMP:

```swift
let config = RTMPConfiguration.facebook(streamKey: "FB-xxxx")
// config.url contains "facebook.com"
// config.enhancedRTMP == false
```

### Kick

``RTMPConfiguration/kick(streamKey:ingestURL:)`` creates a configuration for Kick streaming:

```swift
let config = RTMPConfiguration.kick(streamKey: "kick_key_123")
// config.enhancedRTMP == false
```

### Custom Server

For any RTMP server, use the ``RTMPConfiguration`` initializer directly:

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

### Preset Properties

Every ``PlatformPreset`` exposes platform-specific properties:

| Property | Type | Description |
|----------|------|-------------|
| `url` | `String` | Default ingest URL |
| `chunkSize` | `UInt32` | Recommended chunk size (4096) |
| `requiresTLS` | `Bool` | Whether RTMPS is required |
| `supportsEnhancedRTMP` | `Bool` | Enhanced RTMP v2 support |
| `flashVersion` | `String` | Flash version string |
| `maxBitrate` | `Int` | Maximum recommended bitrate |
| `audioRecommendation` | `String` | Recommended audio settings |

```swift
// Check platform capabilities
PlatformPreset.twitch(.auto).supportsEnhancedRTMP   // true
PlatformPreset.youtube(ingestURL: "").supportsEnhancedRTMP  // true
PlatformPreset.facebook.supportsEnhancedRTMP         // false
PlatformPreset.kick.supportsEnhancedRTMP             // false

// TLS requirements
PlatformPreset.twitch(.auto).requiresTLS  // false (recommended, not required)
PlatformPreset.facebook.requiresTLS       // true
PlatformPreset.kick.requiresTLS           // false
```

## Next Steps

- <doc:GettingStarted> — Quick start with a platform preset
- <doc:EnhancedRTMPGuide> — Enhanced RTMP codec negotiation
- <doc:ReconnectionGuide> — Auto-reconnect configuration
