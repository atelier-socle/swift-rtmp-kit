# CLI Reference

Stream FLV files, test connections, and query server information from the command line.

@Metadata {
    @PageKind(article)
}

## Overview

`rtmp-cli` is a command-line tool built on RTMPKit for streaming FLV files to RTMP servers, testing server connectivity, and querying server capabilities. It supports platform presets, Enhanced RTMP negotiation, and colored terminal output.

### Installation

Build from source:

```bash
swift build -c release
cp .build/release/rtmp-cli /usr/local/bin/
```

### Commands Overview

| Command | Description |
|---------|-------------|
| `publish` | Stream an FLV file to an RTMP server |
| `test-connection` | Test connectivity and measure latency |
| `info` | Query server information and capabilities |

### publish

Stream an FLV file to an RTMP server with real-time progress display.

```bash
rtmp-cli publish [options]
```

**Connection Options:**

| Option | Description |
|--------|-------------|
| `--url` | RTMP server URL (e.g., `rtmps://live.twitch.tv/app`) |
| `--preset` | Platform preset: `twitch`, `youtube`, `facebook`, `kick` |
| `--key` | Stream key (required) |
| `--file` | Path to FLV file to stream (required) |

**Stream Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--ingest` | `auto` | Twitch ingest: `auto`, `us-east`, `us-west`, `europe`, `asia` |
| `--chunk-size` | `4096` | RTMP chunk size |

**Flags:**

| Flag | Description |
|------|-------------|
| `--no-enhanced-rtmp` | Disable Enhanced RTMP negotiation |
| `--loop` | Loop the file continuously |
| `--quiet` | Suppress progress output |

Either `--url` or `--preset` is required, but not both. The `--ingest` option is only valid with `--preset twitch`.

### test-connection

Test RTMP server connectivity by performing a handshake, connect, and createStream sequence, then measuring latency.

```bash
rtmp-cli test-connection [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--url` | RTMP server URL |
| `--preset` | Platform preset: `twitch`, `youtube`, `facebook`, `kick` |
| `--key` | Stream key (required) |
| `--verbose` | Show detailed connection info (bytes sent/received) |

### info

Query RTMP server information and capabilities. Connects, reads the server's connect response, and displays version, capabilities, and Enhanced RTMP codec negotiation results.

```bash
rtmp-cli info [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--url` | RTMP server URL (required) |
| `--key` | Stream key |
| `--json` | Output as JSON |

### Examples

Test connectivity to Twitch:

```bash
rtmp-cli test-connection --preset twitch --key live_xxx
```

Stream an FLV file to Twitch:

```bash
rtmp-cli publish --preset twitch --key live_xxx --file stream.flv
```

Stream to a local RTMP server:

```bash
rtmp-cli publish --url rtmp://localhost:1935/live --key test --file video.flv
```

Stream with looping:

```bash
rtmp-cli publish --preset twitch --key live_xxx --file stream.flv --loop
```

Query server info with JSON output:

```bash
rtmp-cli info --url rtmp://localhost:1935/live --key test --json
```

Query server info in human-readable format:

```bash
rtmp-cli info --url rtmp://localhost:1935/live --key test
```

Stream to YouTube:

```bash
rtmp-cli publish --preset youtube --key xxxx-xxxx-xxxx-xxxx --file stream.flv
```

Stream without Enhanced RTMP:

```bash
rtmp-cli publish --url rtmp://server/app --key xxx --file video.flv --no-enhanced-rtmp
```

## Next Steps

- <doc:TestingGuide> — Mock server for testing CLI commands
- <doc:GettingStarted> — Using RTMPKit as a library
- <doc:StreamingGuide> — Programmatic streaming configuration
