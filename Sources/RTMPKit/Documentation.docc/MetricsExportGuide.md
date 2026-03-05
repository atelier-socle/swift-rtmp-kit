# Metrics Export Guide

Export streaming metrics to Prometheus and StatsD monitoring systems.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit can export streaming metrics to Prometheus (text format) and StatsD (UDP packets) for integration with monitoring dashboards. Both publisher and server metrics are supported.

### Publisher Metrics Snapshot

Take an on-demand metrics snapshot at any time with ``RTMPPublisherStatistics``:

```swift
let publisher = RTMPPublisher()
let stats = await publisher.metricsSnapshot()
// stats.totalBytesSent
// stats.currentVideoBitrate
// stats.currentAudioBitrate
// stats.peakVideoBitrate
// stats.videoFramesSent
// stats.audioFramesSent
// stats.videoFramesDropped
// stats.frameDropRate
// stats.reconnectionCount
// stats.uptimeSeconds
// stats.qualityScore
// stats.qualityGrade
```

### Prometheus Export

``PrometheusExporter`` renders metrics in Prometheus text exposition format:

```swift
let exporter = PrometheusExporter(prefix: "rtmp")
let stats = RTMPPublisherStatistics(
    streamKey: "live_abc123",
    serverURL: "rtmp://live.twitch.tv",
    platform: "twitch",
    totalBytesSent: 52_428_800,
    currentVideoBitrate: 4_200_000,
    currentAudioBitrate: 160_000,
    peakVideoBitrate: 6_000_000,
    videoFramesSent: 18_000,
    audioFramesSent: 43_200,
    videoFramesDropped: 0,
    frameDropRate: 0.0,
    reconnectionCount: 0,
    uptimeSeconds: 600.0,
    qualityScore: 0.92,
    qualityGrade: "excellent",
    timestamp: 0.0
)
let output = exporter.render(stats, labels: ["env": "production"])
// rtmp_bytes_sent_total{env="production",platform="twitch"} 52428800
```

### StatsD Export

``StatsDExporter`` produces metrics in standard StatsD format:

```swift
let exporter = StatsDExporter(prefix: "rtmp")
let lines = exporter.buildPacket(stats)
// rtmp.video_bitrate_bps:4200000|g
// rtmp.bytes_sent:52428800|c
```

### Periodic Export

Wire an exporter to the publisher for automatic periodic export:

```swift
let publisher = RTMPPublisher()
let exporter = MyMetricsExporter()
await publisher.setMetricsExporter(exporter, interval: 0.05)

// ... streaming ...

await publisher.removeMetricsExporter()
```

### Server Metrics

Server metrics are also supported via ``RTMPServerStatistics``:

```swift
let stats = RTMPServerStatistics(
    activeSessionCount: 3,
    totalSessionsConnected: 47,
    totalSessionsRejected: 2,
    totalBytesReceived: 9_876_543,
    currentIngestBitrate: 12_600_000,
    totalVideoFramesReceived: 54_000,
    totalAudioFramesReceived: 129_600,
    activeStreamNames: [],
    sessionMetrics: [:],
    timestamp: 0
)
let exporter = PrometheusExporter()
let output = exporter.render(stats, labels: [:])
// rtmp_server_active_sessions 3

// Get server metrics snapshot
let server = RTMPServer(configuration: .localhost)
let serverStats = await server.metricsSnapshot()
// serverStats.activeSessionCount
```

### Custom Exporters

Implement ``RTMPMetricsExporter`` for custom monitoring integrations:

```swift
actor CustomExporter: RTMPMetricsExporter {
    func export(
        _ statistics: RTMPPublisherStatistics,
        labels: [String: String]
    ) async {
        // Send to your monitoring system
    }

    func export(
        _ statistics: RTMPServerStatistics,
        labels: [String: String]
    ) async {
        // Send server metrics
    }

    func flush() async {}
}
```

### CLI Metrics

```bash
# Prometheus file output
rtmp-cli publish --url rtmp://server/app --key key --file stream.flv \
  --metrics-prometheus /tmp/metrics.txt

# StatsD UDP output
rtmp-cli publish --url rtmp://server/app --key key --file stream.flv \
  --metrics-statsd localhost:8125

# Server metrics
rtmp-cli server start --port 1935 \
  --metrics-prometheus /tmp/server_metrics.txt
```

## Next Steps

- <doc:MonitoringGuide> — Connection statistics and events
- <doc:QualityScoreGuide> — Quality scoring metrics
- <doc:CLIReference> — CLI metrics options
