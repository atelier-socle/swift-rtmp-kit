# AMF3 Guide

Encode and decode AMF3 values with variable-length integers, reference tables, and all 18 type markers.

@Metadata {
    @PageKind(article)
}

## Overview

AMF3 (Action Message Format 3) is a compact binary format used by RTMP type-17 commands. RTMPKit provides full AMF3 encoding and decoding support with ``AMF3Encoder`` and ``AMF3Decoder``, including U29 variable-length integers and three reference tables for strings, objects, and traits.

### AMF3 Types

``AMF3Value`` supports all 18 AMF3 type markers:

| Marker | Type | Description |
|--------|------|-------------|
| 0x00 | `.undefined` | Undefined value |
| 0x01 | `.null` | Null value |
| 0x02 | `.false` | Boolean false |
| 0x03 | `.true` | Boolean true |
| 0x04 | `.integer(Int32)` | 29-bit signed integer (U29) |
| 0x05 | `.double(Double)` | IEEE 754 double |
| 0x06 | `.string(String)` | UTF-8 string with reference table |
| 0x07 | `.xmlDocument(String)` | XML document |
| 0x08 | `.date(Double)` | Date (milliseconds since epoch) |
| 0x09 | `.array` | Associative + dense array |
| 0x0A | `.object(AMF3Object)` | Typed object with traits |
| 0x0B | `.xml(String)` | E4X XML |
| 0x0C | `.byteArray([UInt8])` | Byte array |
| 0x0D-0x0F | `.vectorInt/UInt/Double` | Typed vectors |
| 0x10 | `.vectorObject` | Object vector |
| 0x11 | `.dictionary` | Key-value dictionary |

### Encoding and Decoding

```swift
let encoder = AMF3Encoder()
let decoder = AMF3Decoder()

// Encode a string
let bytes = encoder.encode(.string("hello"))

// Decode back
let value = try decoder.decode(bytes)
// value == .string("hello")
```

### Reference Tables

AMF3 uses three reference tables to deduplicate repeated values:

- **String table** — repeated strings are encoded by index
- **Object table** — repeated objects are encoded by index
- **Traits table** — repeated class definitions are encoded by index

```swift
// Two identical strings — second is encoded as a reference
let encoder = AMF3Encoder()
let bytes = encoder.encode(.array(
    associative: [],
    dense: [.string("hello"), .string("hello")]
))
// The second "hello" is encoded as a 2-byte reference instead of 7 bytes
```

### AMF3 Objects

``AMF3Object`` represents typed objects with ``AMF3Traits``:

```swift
let traits = AMF3Traits(
    className: "com.example.User",
    isExternalizable: false,
    isDynamic: false,
    sealedPropertyNames: ["name", "age"]
)

let obj = AMF3Object(
    traits: traits,
    properties: [
        "name": .string("Alice"),
        "age": .integer(30)
    ]
)

let encoded = AMF3Encoder().encode(.object(obj))
let decoded = try AMF3Decoder().decode(encoded)
```

### AMF0 vs AMF3

| Feature | AMF0 | AMF3 |
|---------|------|------|
| Integer encoding | Fixed-size | U29 variable-length |
| String dedup | No | Reference table |
| Object dedup | No | Reference table |
| Typed vectors | No | Int, UInt, Double, Object |
| RTMP message type | 20 | 17 |
| Default encoding | Yes | Opt-in via `objectEncoding: .amf3` |

### RTMP Type-17 Commands

To use AMF3 encoding for RTMP commands, set ``ObjectEncoding/amf3`` on the configuration:

```swift
var config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
config.objectEncoding = .amf3
```

## Next Steps

- <doc:StreamingGuide> — Streaming with AMF3 encoding
- <doc:EnhancedRTMPGuide> — Enhanced RTMP codec negotiation
- <doc:MetadataGuide> — Metadata encoding
