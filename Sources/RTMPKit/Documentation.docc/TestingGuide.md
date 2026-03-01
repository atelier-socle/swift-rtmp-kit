# Testing Guide

Use the mock server for manual testing and run the unit test suite.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit includes a Python mock RTMP server for manual CLI testing and a comprehensive unit test suite with 1254 tests. This guide covers setting up the mock server, running test scenarios, and measuring code coverage.

### Mock RTMP Server

The mock server at `Scripts/mock-rtmp-server.py` simulates RTMP server behavior for local testing. It handles the RTMP handshake, accepts connect and publish commands, and can simulate various failure modes.

### Starting the Server

```bash
python3 Scripts/mock-rtmp-server.py
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--port` | `1935` | Listen port |
| `--mode` | `default` | Server mode |
| `--verbose` | `false` | Verbose logging |

### Server Modes

| Mode | Description |
|------|-------------|
| `default` | Accept connections and publish commands |
| `enhanced-rtmp` | Accept connections with Enhanced RTMP codec negotiation |
| `reject-connect` | Reject the RTMP connect command |
| `reject-publish` | Accept connect, reject publish |
| `bad-name` | Accept connect, reject publish with BadName |

```bash
# Default mode
python3 Scripts/mock-rtmp-server.py --port 1935

# Enhanced RTMP mode (returns fourCcList in connect response)
python3 Scripts/mock-rtmp-server.py --mode enhanced-rtmp

# Simulate connect rejection
python3 Scripts/mock-rtmp-server.py --mode reject-connect

# Simulate publish rejection
python3 Scripts/mock-rtmp-server.py --mode reject-publish

# Verbose logging
python3 Scripts/mock-rtmp-server.py --verbose
```

### Testing Scenarios

**Test connection:**

```bash
# Terminal 1: start mock server
python3 Scripts/mock-rtmp-server.py

# Terminal 2: test connection
rtmp-cli test-connection --url rtmp://localhost:1935/live --key test
```

**Stream an FLV file:**

```bash
# Terminal 1: start mock server
python3 Scripts/mock-rtmp-server.py

# Terminal 2: stream FLV
rtmp-cli publish --url rtmp://localhost:1935/live --key test --file video.flv
```

**Stream with looping:**

```bash
rtmp-cli publish --url rtmp://localhost:1935/live --key test --file video.flv --loop
```

**Query server info:**

```bash
# Terminal 1: start mock server
python3 Scripts/mock-rtmp-server.py

# Terminal 2: query info
rtmp-cli info --url rtmp://localhost:1935/live --key test
```

**Test Enhanced RTMP negotiation:**

```bash
# Terminal 1: start mock server with Enhanced RTMP
python3 Scripts/mock-rtmp-server.py --mode enhanced-rtmp

# Terminal 2: query info (should show negotiated codecs)
rtmp-cli info --url rtmp://localhost:1935/live --key test
```

**Test error handling:**

```bash
# Terminal 1: start mock server that rejects publish
python3 Scripts/mock-rtmp-server.py --mode reject-publish

# Terminal 2: attempt to publish (should fail gracefully)
rtmp-cli publish --url rtmp://localhost:1935/live --key test --file video.flv
```

### Creating Test FLV Files

Generate a minimal FLV test file with Python:

```bash
python3 -c "
import struct, os
# FLV header: 'FLV' + version 1 + audio+video flags + header size
header = b'FLV\x01\x05' + struct.pack('>I', 9)
# Previous tag size 0
prev = struct.pack('>I', 0)
# Audio tag: type=8, size=2, timestamp=0, streamID=0, payload=0xAF00
tag = struct.pack('B', 8) + struct.pack('>I', 2)[1:] + b'\x00\x00\x00\x00\x00\x00' + b'\xaf\x00'
# Previous tag size
prev2 = struct.pack('>I', 13)
open('test.flv','wb').write(header + prev + tag + prev2)
"
```

### Unit Tests

Run the full test suite:

```bash
swift test
```

The test suite uses Swift Testing (not XCTest) with 1254 tests across 162 suites covering the complete API surface.

### Showcase Tests

The 9 showcase test suites serve as reference implementations for RTMPKit usage patterns:

| Suite | Description |
|-------|-------------|
| `PublisherShowcaseTests` | State machine, presets, URL parsing, transactions, reconnect |
| `ConfigurationShowcaseTests` | Platform presets, custom configs, reconnect policies |
| `EnhancedRTMPShowcaseTests` | FourCC negotiation, HEVC/AV1/Opus, fallback |
| `MonitoringShowcaseTests` | ConnectionMonitor, statistics, status codes, events |
| `TransportShowcaseTests` | MockTransport, DI pattern, transport configuration |
| `FLVShowcaseTests` | FLV headers, audio/video tags, sequence headers |
| `ChunkStreamShowcaseTests` | Chunk multiplexing, assembly, extended timestamps |
| `HandshakeShowcaseTests` | Handshake lifecycle, validation, state machine |
| `AMF0ShowcaseTests` | AMF0 encoding/decoding, all value types |

### Code Coverage

Generate a coverage report:

```bash
swift test --enable-code-coverage

# View the coverage report
xcrun llvm-cov report \
    .build/debug/swift-rtmp-kitPackageTests.xctest/Contents/MacOS/swift-rtmp-kitPackageTests \
    -instr-profile .build/debug/codecov/default.profdata \
    -ignore-filename-regex "Tests/"
```

The current coverage target is 96%+ for RTMPKit sources.

## Next Steps

- <doc:CLIReference> — Full CLI command reference
- <doc:TransportDIGuide> — Mock transport for unit testing
- <doc:GettingStarted> — Getting started with the library API
