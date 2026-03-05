# CLI Reference

Stream FLV files, test connections, record streams, probe bandwidth, and run an ingest server from the command line.

@Metadata {
    @PageKind(article)
}

## Overview

`rtmp-cli` is a command-line tool built on RTMPKit for streaming FLV files to RTMP servers, testing server connectivity, probing bandwidth, recording streams, and running a local RTMP ingest server. It supports platform presets, Enhanced RTMP v2 auto-detection, multi-destination publishing, authentication, and metrics export.

### Installation

Build from source:

```bash
swift build -c release
cp .build/release/rtmp-cli /usr/local/bin/
```

Or via Homebrew:

```bash
brew install atelier-socle/tap/swift-rtmp-kit
```

### Commands Overview

| Command | Description |
|---------|-------------|
| `publish` | Stream an FLV file to one or more RTMP servers |
| `test-connection` | Test connectivity and measure latency |
| `info` | Query server information and capabilities |
| `probe` | Measure bandwidth and connection quality |
| `record` | Publish an FLV file and record the stream to disk |
| `server` | Start a local RTMP ingest server |

### publish

Stream an FLV file to an RTMP server with real-time progress display.

```bash
rtmp-cli publish [options] --file <file>
```

**Connection Options:**

| Option | Description |
|--------|-------------|
| `--url` | RTMP server URL (e.g., `rtmps://live.twitch.tv/app`) |
| `--preset` | Platform preset: `twitch`, `youtube`, `facebook`, `kick` |
| `--key` | Stream key (repeatable for multi-dest) |
| `--file` | Path to FLV file to stream (required) |
| `--dest` | Destination (`platform:key` or `url:key`). Repeatable |

**Stream Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--ingest` | `auto` | Twitch ingest: `auto`, `us-east`, `us-west`, `europe`, `asia` |
| `--chunk-size` | `4096` | RTMP chunk size |

**Flags:**

| Flag | Description |
|------|-------------|
| `--no-enhanced-rtmp` | Disable Enhanced RTMP v2 (force legacy mode, not recommended for HEVC/AV1/VP9) |
| `--loop` | Loop the file continuously |
| `--quiet` | Suppress progress output |

**Authentication:**

| Option | Description |
|--------|-------------|
| `--auth-user` | Auth username (Adobe or simple) |
| `--auth-pass` | Auth password (Adobe or simple) |

**Metrics:**

| Option | Description |
|--------|-------------|
| `--metrics-prometheus` | Write Prometheus metrics to file every 10s |
| `--metrics-statsd` | Push metrics to StatsD (`host:port`) |

Either `--url` or `--preset` is required, but not both. The `--ingest` option is only valid with `--preset twitch`.

### test-connection

Test RTMP server connectivity by performing a handshake, connect, and createStream sequence, then measuring latency.

```bash
rtmp-cli test-connection [options]
```

| Option | Description |
|--------|-------------|
| `--url` | RTMP server URL |
| `--preset` | Platform preset: `twitch`, `youtube`, `facebook`, `kick` |
| `--key` | Stream key (required) |
| `--verbose` | Show detailed connection info (bytes sent/received) |

### info

Query RTMP server information and capabilities. Connects, reads the server's connect response, and displays version, capabilities, and Enhanced RTMP codec negotiation results.

```bash
rtmp-cli info --url <url> [--key <key>] [--json]
```

| Option | Description |
|--------|-------------|
| `--url` | RTMP server URL (required) |
| `--key` | Stream key |
| `--json` | Output as JSON |

### probe

Measure bandwidth and connection quality to an RTMP server. Returns estimated bandwidth, RTT, packet loss, and a recommended quality preset.

```bash
rtmp-cli probe <url> [options]
```

| Option | Description |
|--------|-------------|
| `--duration` | Probe duration in seconds (default: 5) |
| `--quick` | Quick probe (3 seconds) |
| `--thorough` | Thorough probe (10 seconds) |
| `--json` | Output result as JSON |
| `--platform` | Show recommended preset for platform |

### record

Publish an FLV file and record the stream to disk in FLV format.

```bash
rtmp-cli record <file> --url <url> --key <key> [options]
```

| Option | Description |
|--------|-------------|
| `--output` | Output directory for recordings (default: current directory) |
| `--format` | Recording format: `flv`, `video`, `audio`, `all` (default: `flv`) |
| `--segment` | Segment duration in seconds |
| `--max-size` | Maximum total recording size in bytes |

### server

Start a local RTMP ingest server for testing or relay.

```bash
rtmp-cli server start [options]
```

| Option | Default | Description |
|--------|---------|-------------|
| `--port` | `1935` | Port to listen on |
| `--host` | `0.0.0.0` | Bind address |
| `--max-sessions` | `10` | Max concurrent publishers |
| `--allow-key` | (all) | Allow stream key (repeatable) |
| `--dvr` | (off) | Enable auto-DVR to directory |
| `--relay` | (off) | Relay to destination (repeatable, `rtmp://server/app:key`) |
| `--policy` | `open` | Security policy: `open`, `standard`, `strict` |
| `--metrics-prometheus` | (off) | Write Prometheus server metrics to file every 10s |
| `--metrics-statsd` | (off) | Push server metrics to StatsD (`host:port`) |

### Examples

**Basic streaming:**

```bash
# Stream to Twitch
rtmp-cli publish --preset twitch --key live_xxx --file stream.flv

# Stream to YouTube
rtmp-cli publish --preset youtube --key xxxx-xxxx-xxxx-xxxx --file stream.flv

# Stream to a local server
rtmp-cli publish --url rtmp://localhost:1935/live --key test --file video.flv

# Stream with looping
rtmp-cli publish --preset twitch --key live_xxx --file stream.flv --loop
```

**Multi-destination:**

```bash
# Stream to Twitch + YouTube simultaneously
rtmp-cli publish --file stream.flv \
  --dest twitch:live_xxx \
  --dest youtube:xxxx-xxxx-xxxx-xxxx
```

**HEVC auto-detection:**

```bash
# HEVC FLV → Enhanced RTMP v2 enabled automatically
rtmp-cli publish --url rtmp://localhost:1935/live --key test --file hevc_stream.flv
# Output: Video: HEVC (H.265) — Enhanced RTMP v2 will be used
```

**Authentication:**

```bash
# Adobe challenge/response (Wowza)
rtmp-cli publish --url rtmp://wowza.server.com/live --key stream \
  --auth-user broadcaster --auth-pass s3cr3t --file stream.flv
```

**Metrics export:**

```bash
# Prometheus
rtmp-cli publish --url rtmp://server/app --key key --file stream.flv \
  --metrics-prometheus /tmp/metrics.txt

# StatsD
rtmp-cli publish --url rtmp://server/app --key key --file stream.flv \
  --metrics-statsd localhost:8125
```

**Probing and diagnostics:**

```bash
# Test connectivity
rtmp-cli test-connection --preset twitch --key live_xxx

# Probe bandwidth
rtmp-cli probe rtmp://server:1935/live --thorough --platform twitch

# Query server info
rtmp-cli info --url rtmp://localhost:1935/live --key test --json
```

**Recording:**

```bash
# Record a stream to FLV
rtmp-cli record stream.flv --url rtmp://server/app --key key --output /tmp/recordings
```

**Server:**

```bash
# Start a local ingest server with DVR
rtmp-cli server start --port 1935 --allow-key mykey --dvr /tmp/dvr
```

## Next Steps

- <doc:TestingGuide> — Mock server for testing CLI commands
- <doc:GettingStarted> — Using RTMPKit as a library
- <doc:StreamingGuide> — Programmatic streaming configuration
