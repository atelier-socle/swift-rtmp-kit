# Recording Guide

Record live streams to FLV files with segmentation, pause/resume, and size limits.

@Metadata {
    @PageKind(article)
}

## Overview

``StreamRecorder`` records live RTMP streams to FLV files on disk. It supports segmented recording with time-based boundaries, pause/resume, and maximum total size limits.

### Recording Configuration

``RecordingConfiguration`` controls recording behavior:

```swift
let recordingConfig = RecordingConfiguration(
    format: .flv,
    outputDirectory: "/tmp/recordings",
    baseFilename: "stream",
    segmentDuration: 300,         // 5-minute segments (optional)
    maxTotalSize: 500_000_000     // 500 MB total limit (optional)
)
```

| Property | Type | Description |
|----------|------|-------------|
| `format` | `Format` | Output format (`.flv`) |
| `outputDirectory` | `String` | Directory for output files |
| `baseFilename` | `String` | Base name for output files |
| `segmentDuration` | `Double?` | Segment duration in seconds (`nil` = no segmentation) |
| `maxTotalSize` | `UInt64?` | Maximum total size in bytes (`nil` = unlimited) |

### Standalone Recorder

Use ``StreamRecorder`` directly for full control:

```swift
let config = RecordingConfiguration(
    format: .flv,
    outputDirectory: "/tmp/recordings",
    baseFilename: "stream"
)
let recorder = StreamRecorder(configuration: config)
try await recorder.start()

// Write video and audio frames
for i in 0..<100 {
    try await recorder.writeVideo(
        videoBytes,
        timestamp: UInt32(i * 33),
        isKeyframe: i % 30 == 0
    )
    try await recorder.writeAudio(
        audioBytes, timestamp: UInt32(i * 23)
    )
}

// Stop and get the final segment
let segment = try await recorder.stop()
// segment?.videoFrameCount == 100
// segment?.audioFrameCount == 100
// segment?.fileSize > 0
```

### Pause and Resume

Pause recording without stopping the stream — paused frames are discarded:

```swift
let recorder = StreamRecorder(configuration: config)
try await recorder.start()

// Record 10 frames
for i in 0..<10 {
    try await recorder.writeVideo([0x01], timestamp: UInt32(i * 33), isKeyframe: i == 0)
    try await recorder.writeAudio([0xAA], timestamp: UInt32(i * 23))
}

// Pause — frames written during pause are discarded
await recorder.pause()
for i in 10..<20 {
    try await recorder.writeVideo([0x01], timestamp: UInt32(i * 33), isKeyframe: false)
}

// Resume recording
await recorder.resume()
let segment = try await recorder.stop()
// segment?.videoFrameCount == 10  (paused frames excluded)
```

### Segmented Recording

Create multiple files based on time boundaries:

```swift
let config = RecordingConfiguration(
    format: .flv,
    outputDirectory: "/tmp/recordings",
    baseFilename: "segmented",
    segmentDuration: 1.0  // 1-second segments
)
let recorder = StreamRecorder(configuration: config)
try await recorder.start()

// Write 3 seconds of video at ~30fps
for i in 0..<90 {
    try await recorder.writeVideo(
        [0x01], timestamp: UInt32(i * 33),
        isKeyframe: i % 30 == 0
    )
}

let segments = await recorder.completedSegments
// segments.count >= 2 (multiple FLV files created)
_ = try await recorder.stop()
```

### Size Limits

Stop recording automatically when total size exceeds the limit:

```swift
let config = RecordingConfiguration(
    format: .flv,
    outputDirectory: "/tmp/recordings",
    baseFilename: "limit_test",
    maxTotalSize: 1024  // 1 KB limit
)
let recorder = StreamRecorder(configuration: config)
try await recorder.start()

for i in 0..<200 {
    let state = await recorder.state
    guard state == .recording else { break }
    try await recorder.writeVideo(
        [0x01, 0x02, 0x03, 0x04, 0x05],
        timestamp: UInt32(i * 33),
        isKeyframe: i % 30 == 0
    )
}

let state = await recorder.state
// state == .stopped (size limit reached)
```

### Publisher Integration

Start and stop recording through ``RTMPPublisher``:

```swift
let publisher = RTMPPublisher()

// Recording can start before or after connect
try await publisher.startRecording(
    configuration: RecordingConfiguration(
        format: .flv,
        outputDirectory: "/tmp/recordings",
        baseFilename: "pub_test"
    )
)
let isRecording = await publisher.isRecording  // true

try await publisher.publish(configuration: config)

// Send frames — automatically recorded alongside publishing
for i in 0..<10 {
    try await publisher.sendVideo([0x01], timestamp: UInt32(i * 33), isKeyframe: i == 0)
    try await publisher.sendAudio([0xAA], timestamp: UInt32(i * 23))
}

// Stop recording (returns the final segment)
let segment = try await publisher.stopRecording()
// segment?.videoFrameCount > 0
// segment?.audioFrameCount > 0

await publisher.disconnect()
```

Recording events are forwarded to the publisher's ``RTMPEvent`` stream as `.recordingEvent`.

### CLI Recording

Record a stream from the command line:

```bash
# Basic recording
rtmp-cli record stream.flv --url rtmp://server/app --key key

# Record to a specific directory
rtmp-cli record stream.flv --url rtmp://server/app --key key \
  --output /tmp/recordings

# Segmented recording (5-minute segments)
rtmp-cli record stream.flv --url rtmp://server/app --key key \
  --segment 300

# Maximum size limit
rtmp-cli record stream.flv --url rtmp://server/app --key key \
  --max-size 500000000
```

### FLV Output

The recorder produces standard FLV files with correct headers (`FLV` signature, version 1, audio+video flags). Each segment is a valid, self-contained FLV file.

## Next Steps

- <doc:StreamingGuide> — Streaming lifecycle
- <doc:CLIReference> — CLI record command reference
- <doc:FLVCodecProbeGuide> — Detect codecs in FLV files
