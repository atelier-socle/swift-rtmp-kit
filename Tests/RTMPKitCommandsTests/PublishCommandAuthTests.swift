// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import RTMPKit
import Testing

@testable import RTMPKitCommands

// MARK: - Fix B: CLI Adobe auth options

@Suite("PublishCommand — Auth Options")
struct PublishCommandAuthOptionsTests {

    @Test("--auth-user and --auth-pass set adobeChallenge authentication")
    func authUserPassSetsAdobe() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key",
            "--file", "video.flv",
            "--auth-user", "myuser",
            "--auth-pass", "mypass"
        ])
        let config = try cmd.buildConfiguration()
        #expect(
            config.authentication
                == .adobeChallenge(
                    username: "myuser", password: "mypass"
                )
        )
    }

    @Test("no auth options defaults to none authentication")
    func noAuthOptionsDefaults() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key",
            "--file", "video.flv"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.authentication == .none)
    }

    @Test("--auth-user without --auth-pass keeps none authentication")
    func authUserOnlyNoAuth() throws {
        let cmd = try PublishCommand.parse([
            "--url", "rtmp://server/app",
            "--key", "key",
            "--file", "video.flv",
            "--auth-user", "myuser"
        ])
        let config = try cmd.buildConfiguration()
        #expect(config.authentication == .none)
    }
}
