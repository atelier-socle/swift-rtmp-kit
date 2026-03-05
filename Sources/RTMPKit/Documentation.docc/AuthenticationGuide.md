# Authentication Guide

Authenticate with RTMP servers using simple credentials, tokens, or Adobe challenge/response.

@Metadata {
    @PageKind(article)
}

## Overview

RTMPKit supports three authentication methods via ``RTMPAuthentication``: simple username/password, token-based, and Adobe challenge/response (used by Wowza and similar servers).

### Authentication Methods

| Method | Use Case |
|--------|----------|
| `.none` | No authentication (default) |
| `.simple(username:password:)` | Query string credentials |
| `.token(String, expiry:)` | JWT or session token with optional expiry |
| `.adobeChallenge(username:password:)` | Adobe RTMPE MD5 challenge/response |

```swift
// Default: no authentication
let config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
// config.authentication == .none
```

### Simple Authentication

``SimpleAuth`` appends credentials to the connection URL as query parameters:

```swift
var config = RTMPConfiguration(url: "rtmp://server/app", streamKey: "key")
config.authentication = .simple(username: "user1", password: "pass1")
// Connection URL becomes: rtmp://server/app?user=user1&pass=pass1
```

### Token Authentication

``TokenAuth`` uses a bearer token with an optional expiry date:

```swift
var config = RTMPConfiguration(
    url: "rtmp://cdn.example.com/live", streamKey: "stream123"
)
config.authentication = .token("eyJhbGciOiJ...", expiry: Date().addingTimeInterval(3600))

// Token without expiry — never expires
config.authentication = .token("abc123")
// TokenAuth.isExpired(expiry: nil) == false

// If the token is expired, publish() throws RTMPError.tokenExpired
var expiredConfig = config
expiredConfig.authentication = .token("abc123", expiry: Date.distantPast)
do {
    try await publisher.publish(configuration: expiredConfig)
} catch let error as RTMPError {
    // error == .tokenExpired
}
```

### Adobe Challenge/Response

``AdobeChallengeAuth`` implements the two-round authentication protocol used by Wowza and other servers. The server rejects the first connect with a challenge, and the client reconnects with an MD5 response.

```swift
var config = RTMPConfiguration(
    url: "rtmp://wowza.server.com/live", streamKey: "myStream"
)
config.authentication = .adobeChallenge(
    username: "broadcaster", password: "s3cr3t"
)

// RTMPPublisher handles the challenge/response automatically:
// 1. Client connects → server sends _error with challenge parameters
// 2. Client parses salt, challenge, opaque from the rejection description
// 3. Client computes MD5 response and reconnects
// 4. Server accepts the authenticated connection
let publisher = RTMPPublisher()
try await publisher.publish(configuration: config)
```

The challenge parsing extracts `salt`, `challenge`, and `opaque` parameters from the server's rejection description:

```swift
// Parse Wowza challenge from rejection description
let description =
    "[ AccessManager.Reject ] : [ code=403 need auth; authmod=adobe ] "
    + ": /live : ?reason=needauth&user=&salt=6MnrBnKW&challenge=7C5OrwQg&opaque=vbi2V"
let params = AdobeChallengeAuth.parseChallenge(from: description)
// params?.salt == "6MnrBnKW"
// params?.challenge == "7C5OrwQg"
// params?.opaque == "vbi2V"

// Non-Adobe rejection → nil
AdobeChallengeAuth.parseChallenge(from: "NetConnection.Connect.Rejected")
// nil

// Client challenge is random 8-char hex
let c1 = AdobeChallengeAuth.generateClientChallenge()
// c1.count == 8, all hex characters

// Compute auth response
let response = AdobeChallengeAuth.computeResponse(
    username: "broadcaster", password: "s3cr3t",
    challenge: params!, clientChallenge: "a1b2c3d4"
)
// response contains "authmod=adobe", "user=broadcaster", "opaque=vbi2V"
```

### CLI Authentication

```bash
# Adobe or simple auth
rtmp-cli publish --url rtmp://wowza.server.com/live --key stream \
  --auth-user broadcaster --auth-pass s3cr3t --file stream.flv
```

### Error Handling

| Error | Description |
|-------|-------------|
| `RTMPError.authenticationFailed(reason)` | Server rejected credentials |
| `RTMPError.tokenExpired` | Token expiry date has passed |
| `RTMPError.connectRejected` | Server rejected connection (non-auth reason) |

```swift
do {
    try await publisher.publish(configuration: config)
} catch let error as RTMPError {
    switch error {
    case .authenticationFailed(let reason):
        print("Auth failed: \(reason)")
        // error.description == "Authentication failed: \(reason)"
    case .tokenExpired:
        print("Token expired — refresh and retry")
        // error.description == "Authentication token expired"
    default:
        print("Error: \(error.description)")
    }
}
```

## Next Steps

- <doc:StreamingGuide> — Complete streaming lifecycle
- <doc:PlatformPresetsGuide> — Platform-specific configuration
- <doc:CLIReference> — CLI authentication options
