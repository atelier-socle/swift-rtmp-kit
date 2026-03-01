# Reconnection Guide

Configure automatic reconnection with exponential backoff and jitter.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit provides built-in automatic reconnection when a connection is lost during streaming. The ``ReconnectPolicy`` struct controls retry behavior with exponential backoff and configurable jitter to prevent thundering herd problems.

### ReconnectPolicy

``ReconnectPolicy`` has five configurable properties:

| Property | Type | Description |
|----------|------|-------------|
| `maxAttempts` | `Int` | Maximum retry attempts before giving up |
| `initialDelay` | `Double` | Delay before the first retry (seconds) |
| `maxDelay` | `Double` | Maximum delay cap (prevents unbounded growth) |
| `multiplier` | `Double` | Multiplier applied to delay each attempt |
| `jitter` | `Double` | Random jitter factor (0.0-1.0) |

The computed property `isEnabled` returns `true` when `maxAttempts > 0`.

### Presets

RTMPKit includes four preset policies:

| Preset | Attempts | Initial Delay | Max Delay | Multiplier | Jitter |
|--------|----------|---------------|-----------|------------|--------|
| `.default` | 5 | 1.0s | 30.0s | 2.0x | 0.1 |
| `.none` | 0 | — | — | — | — |
| `.aggressive` | 10 | 0.5s | 15.0s | 1.5x | 0.05 |
| `.conservative` | 3 | 2.0s | 60.0s | 3.0x | 0.2 |

```swift
// Default policy (applied automatically)
let config = RTMPConfiguration(
    url: "rtmp://server/app",
    streamKey: "key"
)
// config.reconnectPolicy == .default

// Disable reconnection
let noReconnect = RTMPConfiguration(
    url: "rtmp://server/app",
    streamKey: "key",
    reconnectPolicy: .none
)

// Aggressive reconnection for low-latency scenarios
let aggressive = RTMPConfiguration(
    url: "rtmp://server/app",
    streamKey: "key",
    reconnectPolicy: .aggressive
)
```

### Delay Calculation

The delay for each attempt follows this formula:

```
delay = min(initialDelay x multiplier^attempt, maxDelay) +/- (jitter x random)
```

For the default policy (1.0s initial, 2.0x multiplier, 30s max, 0.1 jitter):

| Attempt | Base Delay | With Jitter (range) |
|---------|------------|---------------------|
| 0 | 1.0s | 0.9s - 1.1s |
| 1 | 2.0s | 1.8s - 2.2s |
| 2 | 4.0s | 3.6s - 4.4s |
| 3 | 8.0s | 7.2s - 8.8s |
| 4 | 16.0s | 14.4s - 17.6s |
| 5+ | exhausted | — |

The `baseDelay(forAttempt:)` method returns the deterministic delay without jitter, while `delay(forAttempt:)` includes random jitter. Both return `nil` when attempts are exhausted.

### Custom Policies

Create a custom policy for specific requirements:

```swift
let customPolicy = ReconnectPolicy(
    maxAttempts: 2,
    initialDelay: 0.1,
    maxDelay: 1.0,
    multiplier: 10,
    jitter: 0
)

let config = RTMPConfiguration(
    url: "rtmp://server/app",
    streamKey: "key",
    reconnectPolicy: customPolicy
)

// With zero jitter, delay() == baseDelay()
customPolicy.baseDelay(forAttempt: 0)  // 0.1
customPolicy.baseDelay(forAttempt: 1)  // 1.0 (capped at maxDelay)
customPolicy.baseDelay(forAttempt: 2)  // nil (exhausted)
```

### State Transitions During Reconnection

When a connection is lost during streaming, the publisher enters the reconnection loop:

1. **Connection lost** — state transitions to `.reconnecting(attempt: 0)`
2. **Wait** — delays for the calculated interval
3. **Retry** — attempts to reconnect and re-negotiate the protocol
4. **Success** — state transitions back to `.publishing`
5. **Failure** — increments attempt count, loops back to step 1
6. **Max retries exceeded** — state transitions to `.failed(.reconnectExhausted(attempts:))`

### Cancellation

Calling ``RTMPPublisher/disconnect()`` during reconnection cancels the loop immediately:

```swift
// Connection lost, publisher is reconnecting...
await publisher.disconnect()
// state == .disconnected (reconnection cancelled)
```

## Next Steps

- <doc:MonitoringGuide> — Track reconnection events and statistics
- <doc:StreamingGuide> — Connection lifecycle and state machine
- <doc:GettingStarted> — Basic setup and quick start
