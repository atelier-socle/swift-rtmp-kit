// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKitCommands

// MARK: - Fix 8: Unique destination IDs

@Suite("Fix 8 — DestinationArgument unique IDs")
struct DestinationArgumentUniqueIDTests {

    @Test("same platform different keys produce different IDs")
    func samePlatformDifferentKeys() {
        let arg1 = DestinationArgument(argument: "twitch:key1")
        let arg2 = DestinationArgument(argument: "twitch:key2")
        #expect(arg1 != nil)
        #expect(arg2 != nil)
        #expect(arg1?.id != arg2?.id)
    }

    @Test("platform ID includes stream key")
    func platformIDIncludesKey() {
        let arg = DestinationArgument(argument: "twitch:live_abc")
        #expect(arg?.id == "twitch/live_abc")
    }

    @Test("URL ID includes stream key")
    func urlIDIncludesKey() {
        let arg = DestinationArgument(
            argument: "rtmp://server.com/app:mykey"
        )
        #expect(arg?.id == "rtmp://server.com/app/mykey")
    }

    @Test("same URL different keys produce different IDs")
    func sameURLDifferentKeys() {
        let arg1 = DestinationArgument(
            argument: "rtmp://server.com/app:key1"
        )
        let arg2 = DestinationArgument(
            argument: "rtmp://server.com/app:key2"
        )
        #expect(arg1 != nil)
        #expect(arg2 != nil)
        #expect(arg1?.id != arg2?.id)
    }
}
