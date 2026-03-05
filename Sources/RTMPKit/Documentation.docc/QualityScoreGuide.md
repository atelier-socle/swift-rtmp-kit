# Quality Score Guide

Monitor connection quality with composite scoring, grades, and degradation warnings.

@Metadata {
    @PageKind(article)
}

## Overview

``ConnectionQualityMonitor`` continuously evaluates connection health during streaming using multiple quality dimensions. It produces ``ConnectionQualityScore`` values with letter grades via an `AsyncStream`, and generates a ``QualityReport`` with trend analysis.

### Quality Grades

``ConnectionQualityScore/Grade`` maps the overall score (0.0-1.0) to letter grades:

| Grade | Description |
|-------|-------------|
| `.excellent` | Excellent connection |
| `.good` | Good connection |
| `.fair` | Fair connection |
| `.poor` | Poor connection |
| `.critical` | Critical — consider stopping |

Grades are `Comparable`: `.excellent > .good > .fair > .poor > .critical`.

### Using the Quality Monitor

``ConnectionQualityMonitor`` operates as a standalone actor with configurable scoring interval and reporting window:

```swift
let monitor = ConnectionQualityMonitor(
    scoringInterval: 0.05, reportingWindow: 5.0
)
await monitor.start()

// Feed measurements
await monitor.recordRTT(15.0)
await monitor.recordBytesSent(500_000, targetBitrate: 4_000_000)
await monitor.recordBitrateAchievement(actual: 4_000_000, configured: 4_000_000)
await monitor.recordSentFrame()
await monitor.recordFrameDrop()

// Read scores from the AsyncStream
var iterator = await monitor.scores.makeAsyncIterator()
let score = await iterator.next()
// score?.overall — 0.0 to 1.0
// score?.grade — .excellent, .good, .fair, .poor, .critical
// score?.hasWarning — true if any dimension is in warning territory

// Read individual dimension scores
let latency = score?.score(for: .latency)
// latency < 0.40 → warning territory

// Generate a quality report
let report = await monitor.generateReport()
// report?.samples.count >= 1
// report?.trend — .improving, .stable, or .degrading

// Stop and get final report
let finalReport = await monitor.stop()
// finalReport?.samples.count >= 1
```

### Excellent vs. Poor Connection

```swift
// Excellent: low RTT, no drops, full bitrate
await monitor.recordRTT(5.0)
await monitor.recordBytesSent(500_000, targetBitrate: 4_000_000)
await monitor.recordBitrateAchievement(actual: 4_000_000, configured: 4_000_000)
// grade >= .good

// Poor: high RTT + frame drops
for _ in 0..<20 { await monitor.recordSentFrame() }
for _ in 0..<10 { await monitor.recordFrameDrop() }
await monitor.recordRTT(180.0)
await monitor.recordBitrateAchievement(actual: 500_000, configured: 4_000_000)
// grade <= .fair
```

### Publisher Integration

The publisher creates a ``ConnectionQualityMonitor`` automatically and exposes quality data through public APIs:

```swift
let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)

// Read current quality score
let score = await publisher.qualityScore
// score?.overall — 0.0 to 1.0
// score?.grade — .excellent, .good, .fair, .poor, .critical

// Stream quality scores via AsyncStream
for await score in await publisher.qualityScores {
    print("Quality: \(score.grade)")
    if score.hasWarning {
        print("Warning: quality degrading")
    }
}

// Generate a quality report with trend analysis
let report = await publisher.qualityReport()
// report?.trend — .improving, .stable, or .degrading
```

### Quality Events

Monitor quality changes through the publisher's event stream:

```swift
for await event in publisher.events {
    switch event {
    case .qualityWarning(let score):
        print("Warning: quality dropped to \(score.grade)")
    case .qualityReportGenerated(let report):
        print("Report: trend=\(report.trend)")
    default:
        break
    }
}
```

## Next Steps

- <doc:MonitoringGuide> — Connection statistics and RTMPEvent
- <doc:AdaptiveBitrateGuide> — ABR responds to quality changes
- <doc:BandwidthProbeGuide> — Pre-stream quality measurement
