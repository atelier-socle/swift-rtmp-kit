# Monitoring Guide

Track connection statistics, measure bitrate, and observe RTMP events in real time.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit provides real-time connection monitoring through ``ConnectionMonitor`` for tracking bytes, frames, bitrate, and RTT. The ``RTMPPublisher/events`` `AsyncStream` delivers state changes, server messages, and periodic statistics snapshots.

### ConnectionMonitor

``ConnectionMonitor`` tracks all streaming activity and provides statistics snapshots. It records bytes sent/received, audio/video frames, dropped frames, and round-trip time:

```swift
var monitor = ConnectionMonitor()
monitor.markConnectionStart(at: 0)

// Record streaming activity
monitor.recordBytesSent(1000, at: timestamp)
monitor.recordVideoFrameSent()
monitor.recordAudioFrameSent()
monitor.recordDroppedFrame()

// Take a snapshot
let stats = monitor.snapshot(currentTime: currentTimestamp)
print("Bytes sent: \(stats.bytesSent)")
print("Frames: \(stats.totalFramesSent)")
print("Drop rate: \(stats.dropRate)%")
```

### ConnectionStatistics

``ConnectionStatistics`` provides an immutable snapshot of the current session:

| Property | Type | Description |
|----------|------|-------------|
| `bytesSent` | `UInt64` | Total bytes sent |
| `bytesReceived` | `UInt64` | Total bytes received |
| `audioFramesSent` | `UInt64` | Audio frames sent |
| `videoFramesSent` | `UInt64` | Video frames sent |
| `droppedFrames` | `UInt64` | Frames dropped |
| `currentBitrate` | `Double` | Current bitrate from sliding window (bps) |
| `averageBitrate` | `Double` | Average bitrate since connection (bps) |
| `connectionUptime` | `Double` | Uptime in seconds |
| `roundTripTime` | `Double?` | Last measured RTT in seconds |
| `lastAcknowledgementTime` | `Double?` | Time of last window ack |

Computed properties:

| Property | Type | Description |
|----------|------|-------------|
| `totalFramesSent` | `UInt64` | `audioFramesSent + videoFramesSent` |
| `dropRate` | `Double` | `droppedFrames / (totalFramesSent + droppedFrames) x 100` |

Access statistics at any time through the publisher:

```swift
let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)

let stats = await publisher.statistics
print("Bytes sent: \(stats.bytesSent)")
print("Bitrate: \(stats.currentBitrate) bps")
print("Uptime: \(stats.connectionUptime)s")
```

### Bitrate Calculation

The monitor uses a sliding window for current bitrate and full-session averaging:

```swift
var monitor = ConnectionMonitor()
monitor.markConnectionStart(at: 0)

// Send 1000 bytes/s for 10 seconds
for sec in 1...10 {
    monitor.recordBytesSent(1000, at: UInt64(sec) * 1_000_000_000)
}

let currentBps = monitor.currentBitrate(at: 10_000_000_000)
// ~9600 bps (sliding window over last 5 seconds)

let averageBps = monitor.averageBitrate(at: 10_000_000_000)
// ~8000 bps (average over full 10 seconds)
```

### RTT Measurement

Round-trip time is measured through RTMP ping/pong:

```swift
monitor.recordPingSent(at: 1_000_000_000)
monitor.recordPongReceived(
    originalTimestamp: 1_000_000_000,
    currentTime: 1_050_000_000
)

let stats = monitor.snapshot(currentTime: 2_000_000_000)
// stats.roundTripTime == 0.05 (50ms)
```

### RTMPStatusCode

``RTMPStatusCode`` parses RTMP server status codes and classifies them as success or error:

```swift
// Parse raw status strings
let code = RTMPStatusCode(rawValue: "NetStream.Publish.Start")
// code == .publishStart

// Classification
RTMPStatusCode.publishStart.isSuccess     // true
RTMPStatusCode.connectSuccess.isSuccess   // true
RTMPStatusCode.publishBadName.isError     // true
RTMPStatusCode.connectRejected.isError    // true

// Categories
RTMPStatusCode.connectSuccess.category    // .connection
RTMPStatusCode.publishStart.category      // .publish
RTMPStatusCode.streamFailed.category      // .stream
```

All 11 known status codes:

| Code | Status | Category |
|------|--------|----------|
| `NetStream.Publish.Start` | Success | Publish |
| `NetStream.Publish.BadName` | Error | Publish |
| `NetStream.Publish.Idle` | Neutral | Publish |
| `NetStream.Publish.Rejected` | Error | Publish |
| `NetStream.Unpublish.Success` | Success | Publish |
| `NetConnection.Connect.Success` | Success | Connection |
| `NetConnection.Connect.Rejected` | Error | Connection |
| `NetConnection.Connect.Closed` | Error | Connection |
| `NetConnection.Connect.Failed` | Error | Connection |
| `NetStream.Play.Reset` | Neutral | Stream |
| `NetStream.Failed` | Error | Stream |

### RTMPEvent

``RTMPEvent`` carries events through the ``RTMPPublisher/events`` `AsyncStream`:

| Event | Description |
|-------|-------------|
| `.stateChanged(_)` | Publisher state changed |
| `.serverMessage(code:description:)` | Server sent an onStatus message |
| `.acknowledgementReceived(sequenceNumber:)` | Window acknowledgement received |
| `.pingReceived` | Server sent a ping request |
| `.error(_)` | An ``RTMPError`` occurred |
| `.statisticsUpdate(_)` | Periodic statistics snapshot |

```swift
let eventTask = Task {
    for await event in publisher.events {
        switch event {
        case .stateChanged(let state):
            print("State: \(state)")
        case .serverMessage(let code, let description):
            print("Server: \(code) — \(description)")
        case .statisticsUpdate(let stats):
            print("Bitrate: \(stats.currentBitrate) bps")
        case .error(let error):
            print("Error: \(error)")
        default:
            break
        }
    }
}
```

## Next Steps

- <doc:ReconnectionGuide> — Auto-reconnect configuration
- <doc:StreamingGuide> — Connection lifecycle and state machine
- <doc:TransportDIGuide> — Testing with mock transports
