# Multi-Destination Guide

Stream simultaneously to Twitch, YouTube, Facebook, and custom servers with per-destination state and failure isolation.

@Metadata {
    @PageKind(article)
}

## Overview

``MultiPublisher`` fans out audio and video frames to multiple RTMP servers simultaneously. Each destination has independent state, statistics, and failure handling. If one destination fails, the others continue streaming.

### Creating Destinations

Each destination is a ``PublishDestination`` with a unique ID and an ``RTMPConfiguration``:

```swift
let twitch = PublishDestination(
    id: "twitch",
    configuration: .twitch(streamKey: "live_xxx")
)
let youtube = PublishDestination(
    id: "youtube",
    configuration: .youtube(streamKey: "xxxx-xxxx-xxxx-xxxx")
)
let facebook = PublishDestination(
    id: "facebook",
    configuration: .facebook(streamKey: "FB-xxxx")
)

// Convenience init with URL and stream key
let custom = PublishDestination(
    id: "custom", url: "rtmp://server/app", streamKey: "key"
)
```

### Multi-Destination Publish

```swift
let multi = MultiPublisher()
try await multi.addDestination(twitch)
try await multi.addDestination(youtube)
try await multi.addDestination(facebook)

// All destinations start in .idle
let states = await multi.destinationStates
// states["twitch"] == .idle

// Connect all idle destinations
await multi.startAll()

// Send frames — automatically fanned out to all .streaming destinations
await multi.sendVideo(naluData, timestamp: 0, isKeyframe: true)
await multi.sendAudio(aacFrame, timestamp: 0)

// Send metadata to all destinations
await multi.sendMetadata(streamMeta)
await multi.sendText("Now playing", timestamp: 10.0)
await multi.sendCuePoint(cuePoint)
await multi.sendCaption(captionData)

// Disconnect all
await multi.stopAll()
```

### Destination States

``DestinationState`` tracks the lifecycle of each destination:

| State | Description |
|-------|-------------|
| `.idle` | Added but not started |
| `.connecting` | Connection in progress |
| `.streaming` | Actively receiving frames |
| `.reconnecting(attempt:)` | Auto-reconnecting |
| `.stopped` | Gracefully stopped |
| `.failed(Error)` | Failed with error |

```swift
// Check individual destination state
let state = await multi.state(for: "twitch")

// Start or stop a specific destination
try await multi.start(id: "youtube")
try await multi.stop(id: "youtube")
```

### Failure Policies

``MultiPublisherFailurePolicy`` controls what happens when a destination fails:

| Policy | Behavior |
|--------|----------|
| `.continueOnFailure` | Other destinations continue streaming (default) |
| `.stopAllOnFailure(count: N)` | All destinations stop after N failures |

```swift
// Default: failures are isolated
let multi = MultiPublisher()
let policy = await multi.failurePolicy  // .continueOnFailure

// Stop everything on first failure
await multi.setFailurePolicy(.stopAllOnFailure(count: 1))

// Tolerate one failure, stop on second
await multi.setFailurePolicy(.stopAllOnFailure(count: 2))
```

### Per-Destination Events and Statistics

Monitor each destination independently through ``MultiPublisherEvent``:

```swift
let eventTask = Task {
    for await event in multi.events {
        switch event {
        case .stateChanged(let destinationID, let state):
            print("\(destinationID): \(state)")
        case .destinationEvent(let destinationID, let rtmpEvent):
            print("\(destinationID) RTMP: \(rtmpEvent)")
        case .statisticsUpdated(let stats):
            print("Active: \(stats.activeCount)")
            print("Total bytes: \(stats.totalBytesSent)")
        case .failureThresholdReached(let failedCount):
            print("Threshold: \(failedCount) destinations failed")
        }
    }
}

// Aggregate statistics
let stats = await multi.statistics
// stats.totalBytesSent, stats.activeCount, stats.totalDroppedFrames
// stats.perDestination — per-destination ConnectionStatistics

// Per-destination statistics
let twitchStats = await multi.statistics(for: "twitch")
// twitchStats?.bytesSent
```

### Hot Add and Remove

Add or remove destinations during an active stream:

```swift
// Hot-add a third destination while streaming
try await multi.addDestination(
    PublishDestination(id: "d3", url: "rtmp://h/app", streamKey: "k3")
)
let state = await multi.state(for: "d3")  // .idle

// Hot-remove — leaves other destinations unaffected
try await multi.removeDestination(id: "d3")

// Replace a failed destination
let failedState = await multi.state(for: "d1")
if case .failed = failedState {
    try await multi.removeDestination(id: "d1")
    try await multi.addDestination(
        PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1-new")
    )
}
```

### Per-Destination ABR

Each destination can have its own adaptive bitrate policy:

```swift
var twitchConfig = RTMPConfiguration.twitch(streamKey: "live_xxx")
twitchConfig.adaptiveBitrate = .responsive(min: 1_000_000, max: 6_000_000)

var youtubeConfig = RTMPConfiguration.youtube(streamKey: "yyyy")
youtubeConfig.adaptiveBitrate = .conservative(min: 500_000, max: 4_000_000)

try await multi.addDestination(
    PublishDestination(id: "twitch", configuration: twitchConfig)
)
try await multi.addDestination(
    PublishDestination(id: "youtube", configuration: youtubeConfig)
)
```

### Error Handling

``MultiPublisherError`` covers destination management errors:

| Error | Description |
|-------|-------------|
| `.destinationAlreadyExists(id)` | A destination with this ID already exists |
| `.destinationNotFound(id)` | No destination with this ID exists |

```swift
do {
    try await multi.addDestination(
        PublishDestination(id: "twitch", configuration: .twitch(streamKey: "key2"))
    )
} catch let error as MultiPublisherError {
    // error == .destinationAlreadyExists("twitch")
}
```

### CLI Multi-Destination

From the command line, use `--dest` to specify multiple destinations:

```bash
rtmp-cli publish --file stream.flv \
  --dest twitch:live_xxx \
  --dest youtube:xxxx-xxxx-xxxx-xxxx
```

## Next Steps

- <doc:StreamingGuide> — Single-destination streaming
- <doc:MonitoringGuide> — Per-destination statistics
- <doc:AdaptiveBitrateGuide> — ABR per destination
