# Platform Presets Guide

Configure streaming for Twitch, YouTube, Facebook, Kick, Instagram, TikTok, Rumble, LinkedIn, Trovo, Twitter, and custom RTMP servers.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit provides one-line platform presets that configure the server URL, TLS, chunk size, Enhanced RTMP, and flash version for 10 major streaming platforms. Use presets for quick setup, or build a custom ``RTMPConfiguration`` for any RTMP server.

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

### Instagram

``RTMPConfiguration/instagram(streamKey:)`` creates a configuration for Instagram Live. Instagram requires RTMPS and does not support Enhanced RTMP:

```swift
let config = RTMPConfiguration.instagram(streamKey: "IGLive_abc123")
// config.url starts with "rtmps://"
// config.preset?.requiresTLS == true
// config.enhancedRTMP == false
```

### TikTok

``RTMPConfiguration/tiktok(streamKey:)`` creates a configuration for TikTok Live. TikTok requires RTMPS:

```swift
let config = RTMPConfiguration.tiktok(streamKey: "tiktok_stream_key")
// config.url contains "tiktok.com"
// config.preset?.requiresTLS == true
```

### Rumble

``RTMPConfiguration/rumble(streamKey:)`` creates a configuration for Rumble streaming. Rumble uses plain RTMP (no TLS):

```swift
let config = RTMPConfiguration.rumble(streamKey: "my_rumble_key")
// config.url starts with "rtmp://"
// config.preset?.requiresTLS == false
```

### LinkedIn, Trovo, and Twitter

Additional platforms are available through the ``StreamingPlatformRegistry``:

```swift
// LinkedIn Live
let linkedinConfig = StreamingPlatformRegistry.configuration(
    platform: "linkedin", streamKey: "linkedin_stream_key"
)

// Trovo Live
let trovoConfig = StreamingPlatformRegistry.configuration(
    platform: "trovo", streamKey: "trovo_key"
)

// Twitter/Periscope
let twitterConfig = StreamingPlatformRegistry.configuration(
    platform: "twitter", streamKey: "periscope_key"
)
```

### Streaming Platform Registry

``StreamingPlatformRegistry`` provides a programmatic way to discover and configure all 10 supported platforms:

```swift
// Case-insensitive platform lookup
let preset = StreamingPlatformRegistry.platform(named: "LinkedIn") // .linkedin
let preset2 = StreamingPlatformRegistry.platform(named: "TROVO")   // .trovo
let unknown = StreamingPlatformRegistry.platform(named: "xyz")     // nil

// Create configuration from platform name
let config = StreamingPlatformRegistry.configuration(
    platform: "twitter", streamKey: "periscope_key"
)
// config?.streamKey == "periscope_key"

// Iterate all 10 platforms
for preset in StreamingPlatformRegistry.allPlatforms {
    let config = StreamingPlatformRegistry.configuration(
        platform: preset.name, streamKey: "test_key"
    )
    print("\(preset.name): \(config?.url ?? "N/A")")
}

// List TLS-required platforms
for preset in StreamingPlatformRegistry.tlsRequiredPlatforms {
    let config = StreamingPlatformRegistry.configuration(
        platform: preset.name, streamKey: "test"
    )
    // All TLS-required platforms use rtmps://
    assert(config?.url.hasPrefix("rtmps://") == true)
}
```

### Multi-Platform with Registry

Use the registry to add all platforms to a ``MultiPublisher``:

```swift
let multi = MultiPublisher()
for preset in StreamingPlatformRegistry.allPlatforms {
    guard let config = StreamingPlatformRegistry.configuration(
        platform: preset.name, streamKey: "test_key"
    ) else { continue }
    try multi.addDestination(
        PublishDestination(id: preset.name, configuration: config)
    )
}
// 10 destinations added
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

### Combining Presets with ABR and Authentication

New platform presets work with all RTMPKit features:

```swift
var config = RTMPConfiguration.tiktok(streamKey: "key")
config.adaptiveBitrate = .responsive(min: 500_000, max: 4_000_000)
config.authentication = .token("tiktok_auth_token")
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
- <doc:MultiDestinationGuide> — Multi-destination publishing
- <doc:ReconnectionGuide> — Auto-reconnect configuration
