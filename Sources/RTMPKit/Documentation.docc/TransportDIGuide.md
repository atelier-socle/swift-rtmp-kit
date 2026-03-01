# Transport Dependency Injection Guide

Test your streaming app without a real RTMP server using mock transports.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit uses a protocol-based transport layer that allows you to replace the real network connection with a test double. This lets you test your streaming logic in isolation without connecting to an actual RTMP server.

### Why Dependency Injection

Testing a live streaming application against real servers is slow, unreliable, and hard to automate. With transport DI, you can:

- Test your publish logic without network access
- Simulate server errors and edge cases
- Verify the exact bytes your app sends
- Run tests in CI without external dependencies

### RTMPTransportProtocol

``RTMPTransportProtocol`` defines the transport contract that all implementations must satisfy:

```swift
public protocol RTMPTransportProtocol {
    func connect(host: String, port: Int, useTLS: Bool) async throws
    func send(_ bytes: [UInt8]) async throws
    func receive() async throws -> RTMPMessage
    func close() async throws
    var isConnected: Bool { get async }
}
```

Both ``NIOTransport`` (production) and `MockTransport` (testing) conform to this protocol.

### MockTransport

`MockTransport` is a test double that replaces the real network. It records all interactions and lets you script server responses:

```swift
// 1. Create a MockTransport
let mock = MockTransport()

// 2. Script a server response
let ackMsg = RTMPMessage(
    controlMessage: .windowAcknowledgementSize(2_500_000)
)
mock.scriptedMessages = [ackMsg]

// 3. Connect through the mock
try await mock.connect(host: "127.0.0.1", port: 1935, useTLS: false)
mock.didConnect      // true
mock.connectHost     // "127.0.0.1"
mock.connectPort     // 1935
mock.connectUseTLS   // false

// 4. Receive scripted messages
let received = try await mock.receive()
// received.typeID == RTMPMessage.typeIDWindowAckSize
```

### Capturing Sent Data

Verify the exact bytes your app sends to the server:

```swift
let mock = MockTransport()
try await mock.connect(host: "server", port: 1935, useTLS: false)

// Send bytes — mock records them
let videoBytes: [UInt8] = [0x17, 0x01, 0x00, 0x00, 0x00, 0xAB, 0xCD]
try await mock.send(videoBytes)

let audioBytes: [UInt8] = [0xAF, 0x01, 0xCA]
try await mock.send(audioBytes)

// Verify outgoing data
mock.sentBytes.count    // 2
mock.sentBytes[0]       // videoBytes
mock.sentBytes[1]       // audioBytes
```

### Simulating Errors

Script errors to test your error handling:

```swift
let mock = MockTransport()
mock.nextError = TransportError.connectionTimeout

do {
    try await mock.connect(host: "bad.host", port: 1935, useTLS: false)
} catch {
    // error == TransportError.connectionTimeout
}
mock.isConnected  // false
```

### Injecting into RTMPPublisher

Pass a mock transport to ``RTMPPublisher/init(transport:)`` for testing:

```swift
// 1. Create a mock transport
let mock = MockTransport()

// 2. Inject into RTMPPublisher
let publisher = RTMPPublisher(transport: mock)

// 3. The publisher uses the mock instead of NIO
let state = await publisher.state
// state == .idle

// 4. Test your publish logic without real network
mock.didConnect  // false — nothing connected yet

await publisher.disconnect()
```

### TransportConfiguration

``TransportConfiguration`` controls TCP/TLS transport settings:

| Preset | Timeout | Buffer Size | TCP No Delay | TLS Min |
|--------|---------|-------------|--------------|---------|
| `.default` | 15s | 64 KB | `true` | TLS 1.2 |
| `.lowLatency` | 10s | 32 KB | `true` | TLS 1.2 |

```swift
// Default configuration
let config = TransportConfiguration.default
// config.connectTimeout == 15
// config.receiveBufferSize == 65536
// config.sendBufferSize == 65536

// Low-latency preset
let lowLatency = TransportConfiguration.lowLatency
// lowLatency.connectTimeout == 10
// lowLatency.receiveBufferSize == 32768

// Custom configuration
let custom = TransportConfiguration(
    connectTimeout: 30,
    receiveBufferSize: 128 * 1024,
    sendBufferSize: 128 * 1024,
    tcpNoDelay: false,
    tlsMinimumVersion: .tlsv13
)
```

Transport configuration is stored in ``RTMPConfiguration``:

```swift
let config = RTMPConfiguration(
    url: "rtmp://server/app",
    streamKey: "key",
    transportConfiguration: .lowLatency
)
// config.transportConfiguration.connectTimeout == 10
```

### NIOTransport

``NIOTransport`` is the production transport built on SwiftNIO. It provides TCP/TLS connections with configurable buffer sizes and timeouts. The publisher uses it by default:

```swift
let publisher = RTMPPublisher()
// Uses NIOTransport internally
```

### HLSKit Bridge Pattern

RTMPKit has **no dependency on [HLSKit](https://github.com/atelier-socle/swift-hls-kit)**. The bridge conformance is implemented in the consuming app or a dedicated glue package. This keeps each library independent and composable.

Each transport library in the Atelier Socle ecosystem follows the same pattern:

1. Each library defines its own client actor with `publish()`, `send()`, `disconnect()`
2. HLSKit defines a transport protocol for each push target
3. The consuming app bridges the two with an extension conformance
4. HLSKit's `LivePipeline` accepts any conforming transport

## Next Steps

- <doc:TestingGuide> — Mock server and testing guide
- <doc:StreamingGuide> — Production streaming configuration
- <doc:MonitoringGuide> — Monitor transport connection health
