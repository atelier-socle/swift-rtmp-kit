# Bandwidth Probe Guide

Measure available bandwidth and get quality preset recommendations before streaming.

@Metadata {
    @PageKind(article)
}

## Overview

``BandwidthProbe`` measures the available bandwidth, RTT, and connection quality to an RTMP server before streaming begins. The probe result includes a recommended bitrate, signal quality score, and quality tier for optimal streaming.

### Probing Bandwidth

```swift
let probe = BandwidthProbe(
    configuration: .init(
        duration: 0.3, burstInterval: 0.05, warmupBursts: 1
    )
)
let result = try await probe.probe(url: "rtmp://server:1935/live")

print("Bandwidth: \(result.estimatedBandwidth) bps")
print("RTT: min=\(result.minRTT)ms avg=\(result.averageRTT)ms max=\(result.maxRTT)ms")
print("Signal quality: \(result.signalQuality)")
print("Quality tier: \(result.qualityTier)")
print("Recommended bitrate: \(result.recommendedBitrate) bps")
print("Summary: \(result.summary)")
```

### Probe Configuration

Control the probe duration and burst parameters:

```swift
// Quick probe — fewer bursts, faster result
let quickProbe = BandwidthProbe(
    configuration: .init(duration: 0.2, burstInterval: 0.05, warmupBursts: 0)
)

// Thorough probe — more bursts, more accurate
let thoroughProbe = BandwidthProbe(
    configuration: .init(duration: 0.5, burstInterval: 0.05, warmupBursts: 0)
)

// Thorough sends more bursts than quick
let quickResult = try await quickProbe.probe(url: "rtmp://server/app")
let thoroughResult = try await thoroughProbe.probe(url: "rtmp://server/app")
// thoroughResult.burstsSent > quickResult.burstsSent
```

### Probe Result

``ProbeResult`` provides comprehensive connection metrics:

| Property | Type | Description |
|----------|------|-------------|
| `estimatedBandwidth` | `Int` | Estimated bandwidth in bps |
| `minRTT` | `Double` | Minimum RTT in milliseconds |
| `averageRTT` | `Double` | Average RTT in milliseconds |
| `maxRTT` | `Double` | Maximum RTT in milliseconds |
| `packetLossRate` | `Double` | Packet loss ratio (0.0-1.0) |
| `signalQuality` | `Double` | Connection quality score (0.0-1.0) |
| `recommendedBitrate` | `Int` | Recommended streaming bitrate |
| `qualityTier` | `QualityTier` | Recommended quality tier |
| `probeDuration` | `Double` | Duration of the probe in seconds |
| `burstsSent` | `Int` | Number of bursts sent |
| `summary` | `String` | Human-readable summary |

### Quality Preset Selection

``QualityPresetSelector`` maps probe results to a 6-tier quality ladder:

| Tier | Resolution | Frame Rate | Bitrate |
|------|-----------|------------|---------|
| 360p30 | 640x360 | 30 fps | ~1 Mbps |
| 480p30 | 854x480 | 30 fps | ~2 Mbps |
| 720p30 | 1280x720 | 30 fps | ~3 Mbps |
| 720p60 | 1280x720 | 60 fps | ~4.5 Mbps |
| 1080p30 | 1920x1080 | 30 fps | ~5 Mbps |
| 1080p60 | 1920x1080 | 60 fps | ~8 Mbps |

```swift
// Select quality for a platform based on probe results
let config = QualityPresetSelector.select(
    for: result, platform: .twitch(.auto),
    streamKey: "live_abc123"
)
// config.initialMetadata?.videoBitrate — selected bitrate
// config.initialMetadata?.height — selected resolution

// Poor connection selects low quality tier
let poorResult = ProbeResult(
    estimatedBandwidth: 1_000_000,
    minRTT: 50, averageRTT: 100, maxRTT: 300,
    packetLossRate: 0.1,
    probeDuration: 5, burstsSent: 40,
    signalQuality: 0.35
)
let poorConfig = QualityPresetSelector.select(
    for: poorResult, platform: .twitch(.auto), streamKey: "k"
)
// poorConfig.initialMetadata?.height == 360  (lowest tier)

// Platform max bitrate is respected
let igConfig = QualityPresetSelector.select(
    for: highBandwidthResult, platform: .instagram,
    streamKey: "ig_key"
)
// Capped to Instagram's 3500 kbps max

// Quality ladder has 6 tiers
QualityPresetSelector.qualityLadder.count  // 6
```

### CLI Probing

```bash
# Standard probe
rtmp-cli probe rtmp://server:1935/live

# Quick probe with platform recommendation
rtmp-cli probe rtmp://server:1935/live --quick --platform twitch

# Thorough probe with JSON output
rtmp-cli probe rtmp://server:1935/live --thorough --json
```

## Next Steps

- <doc:AdaptiveBitrateGuide> — Configure ABR based on probe results
- <doc:QualityScoreGuide> — Monitor quality during streaming
- <doc:CLIReference> — CLI probe command reference
