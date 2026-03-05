# Adaptive Bitrate Guide

Dynamically adjust video bitrate based on network conditions with configurable ABR policies.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit provides adaptive bitrate (ABR) streaming that automatically adjusts the video bitrate in response to network conditions. The system monitors RTT, buffer saturation, and frame drops to recommend bitrate changes, and optionally drops non-essential frames to maintain stream stability.

### ABR Policies

``AdaptiveBitratePolicy`` provides four preset policies and a custom option:

| Policy | Step Down | Step Up | Stability Duration | Behavior |
|--------|-----------|---------|-------------------|----------|
| `.disabled` | — | — | — | No ABR, fixed bitrate |
| `.conservative` | 0.80 | — | 20s | Slow step-down, slow recovery |
| `.responsive` | 0.75 | 1.10 | — | Balanced step-down and recovery |
| `.aggressive` | 0.65 | 1.15 | — | Fast step-down, fast recovery |
| `.custom(config)` | User-defined | User-defined | User-defined | Full control |

```swift
// Conservative: live events, podcasts — slow reactions, stable bitrate
let conservative = AdaptiveBitratePolicy.conservative(min: 500_000, max: 4_000_000)
// conservative.configuration?.stepDown == 0.80
// conservative.configuration?.upStabilityDuration == 20.0

// Responsive: gaming, sport — balanced reactions
let responsive = AdaptiveBitratePolicy.responsive(min: 1_000_000, max: 6_000_000)
// responsive.configuration?.stepDown == 0.75
// responsive.configuration?.stepUp == 1.10
// responsive.configuration?.measurementWindow == 3.0

// Aggressive: casual streaming — fast reactions
let aggressive = AdaptiveBitratePolicy.aggressive(min: 300_000, max: 3_000_000)
// aggressive.configuration?.stepDown == 0.65
// aggressive.configuration?.stepUp == 1.15
// aggressive.configuration?.downTriggerThreshold == 0.15

// Disabled: fixed bitrate, no ABR
AdaptiveBitratePolicy.disabled.configuration // nil
```

### Publisher Integration

Enable ABR on any ``RTMPConfiguration``:

```swift
var config = RTMPConfiguration.twitch(streamKey: "live_abc123")
config.adaptiveBitrate = .responsive(min: 1_000_000, max: 6_000_000)

let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)

// Read current bitrate
let currentBitrate = await publisher.currentVideoBitrate

// Force a manual bitrate override (only when ABR is enabled)
await publisher.forceVideoBitrate(1_200_000)
let updated = await publisher.currentVideoBitrate  // 1_200_000

// forceVideoBitrate is a no-op when ABR is disabled
```

The default ``RTMPConfiguration`` has ABR disabled:

```swift
let config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
// config.adaptiveBitrate == .disabled
// config.frameDroppingStrategy == .default
```

### Custom ABR Configuration

For fine-grained control, use ``AdaptiveBitrateConfiguration`` with all 8 parameters:

```swift
let abrConfig = AdaptiveBitrateConfiguration(
    minBitrate: 200_000,
    maxBitrate: 8_000_000,
    stepDown: 0.70,                   // Step down by 30%
    stepUp: 1.20,                     // Step up by 20%
    downTriggerThreshold: 0.30,       // RTT spike threshold
    upStabilityDuration: 12.0,        // Wait 12s before stepping up
    measurementWindow: 4.0,           // EWMA window
    dropRateTriggerThreshold: 0.04    // 4% drop rate triggers step-down
)
config.adaptiveBitrate = .custom(abrConfig)
```

### Network Condition Monitor

``NetworkConditionMonitor`` runs autonomously and produces ``BitrateRecommendation`` values with a ``BitrateChangeReason``:

| Reason | Trigger |
|--------|---------|
| `.rttSpike` | RTT exceeded baseline by `downTriggerThreshold` |
| `.congestionDetected` | Pending bytes exceed buffer threshold |
| `.dropRateExceeded` | Frame drop rate above `dropRateTriggerThreshold` |
| `.bandwidthRecovered` | EWMA bandwidth > current bitrate × 1.15 after stability period |
| `.manual` | Manual override via ``NetworkConditionMonitor/forceRecommendation(bitrate:)`` |

The monitor enforces bounds — bitrate never exceeds `maxBitrate` and never falls below `minBitrate`. A cooldown period prevents oscillation between step-down and step-up.

```swift
// Standalone monitor usage (advanced)
let monitor = NetworkConditionMonitor(
    policy: .responsive(min: 500_000, max: 6_000_000),
    initialBitrate: 3_000_000
)
await monitor.start()

// Feed measurements
await monitor.recordRTT(0.05)
await monitor.recordBytesSent(10_000, pendingBytes: 500)
await monitor.recordSentFrame()
await monitor.recordDroppedFrame()

// Check network snapshot
let snapshot = await monitor.currentSnapshot
// snapshot?.roundTripTime, snapshot?.pendingBytes, snapshot?.dropRate

// Force manual override
await monitor.forceRecommendation(bitrate: 1_500_000)

// Consume recommendations via the public AsyncStream
for await rec in await monitor.recommendations {
    print("Bitrate: \(rec.previousBitrate) → \(rec.recommendedBitrate)")
    print("Reason: \(rec.reason)")  // .manual, .rttSpike, etc.
}

// Reset all state
await monitor.reset()
// currentBitrate resets to initialBitrate, snapshot cleared
```

### Frame Dropping Strategy

``FrameDroppingStrategy`` controls which frames are dropped first during congestion:

```swift
var config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")

// Default: B-frames dropped first, P-frames under severe congestion
config.frameDroppingStrategy = .default
// .default.maxConsecutiveNonKeyframeDrops == 30

// Aggressive: drops P-frames sooner, 60 max consecutive drops
config.frameDroppingStrategy = .aggressive
// .aggressive.maxConsecutiveNonKeyframeDrops == 60

// Conservative: higher threshold, 10 max consecutive drops
config.frameDroppingStrategy = .conservative
// .conservative.maxConsecutiveNonKeyframeDrops == 10
```

Drop priority is always: B-frames first, then P-frames under severe congestion. I-frames (keyframes) are **never** dropped to maintain decoder state. After `maxConsecutiveNonKeyframeDrops`, the strategy requests a keyframe to recover the GOP.

### ABR Events

Monitor bitrate recommendations through the publisher's event stream:

```swift
for await event in publisher.events {
    if case .bitrateRecommendation(let rec) = event {
        print("Bitrate: \(rec.previousBitrate) → \(rec.recommendedBitrate)")
        print("Reason: \(rec.reason)")
    }
}
```

The ABR monitor starts automatically on `publish()` when ABR is enabled, and stops cleanly on `disconnect()`. On reconnection, ABR state resets to initial values.

## Next Steps

- <doc:MonitoringGuide> — Track bitrate changes and frame drops
- <doc:QualityScoreGuide> — Connection quality scoring
- <doc:BandwidthProbeGuide> — Measure bandwidth before streaming
