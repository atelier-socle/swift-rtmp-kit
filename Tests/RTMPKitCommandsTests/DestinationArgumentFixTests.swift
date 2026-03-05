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

    @Test("same URL with port, different keys produce different IDs")
    func sameURLWithPortDifferentKeys() {
        let arg1 = DestinationArgument(
            argument: "rtmp://localhost:19350/live:stream_A"
        )
        let arg2 = DestinationArgument(
            argument: "rtmp://localhost:19350/live:stream_B"
        )
        #expect(arg1 != nil)
        #expect(arg2 != nil)
        #expect(arg1?.id != arg2?.id)
        #expect(arg1?.id == "rtmp://localhost:19350/live/stream_A")
        #expect(arg2?.id == "rtmp://localhost:19350/live/stream_B")
    }

    @Test("same URL with port, same key produce same ID")
    func sameURLWithPortSameKey() {
        let arg1 = DestinationArgument(
            argument: "rtmp://localhost:19350/live:same_key"
        )
        let arg2 = DestinationArgument(
            argument: "rtmp://localhost:19350/live:same_key"
        )
        #expect(arg1 != nil)
        #expect(arg2 != nil)
        #expect(arg1?.id == arg2?.id)
    }

    @Test("different URLs, same key produce different IDs")
    func differentURLsSameKey() {
        let arg1 = DestinationArgument(
            argument: "rtmp://a.com/live:key1"
        )
        let arg2 = DestinationArgument(
            argument: "rtmp://b.com/live:key1"
        )
        #expect(arg1 != nil)
        #expect(arg2 != nil)
        #expect(arg1?.id != arg2?.id)
    }

    @Test("URL without embedded key is accepted with empty stream key")
    func urlWithoutEmbeddedKey() {
        let arg = DestinationArgument(
            argument: "rtmp://localhost:19350/live"
        )
        #expect(arg != nil)
        #expect(arg?.id == "rtmp://localhost:19350/live")
        #expect(arg?.configuration.streamKey == "")
    }

    @Test("plain URL destinations paired with --key produce different IDs")
    func plainURLPairedWithKeys() throws {
        let cmd = try PublishCommand.parse([
            "--dest", "rtmp://localhost:19350/live",
            "--key", "stream_A",
            "--dest", "rtmp://localhost:19350/live",
            "--key", "stream_B",
            "--file", "/tmp/test.flv"
        ])
        let destinations = try cmd.buildDestinations()
        #expect(destinations.count == 2)
        #expect(destinations[0].id != destinations[1].id)
        #expect(destinations[0].configuration.streamKey == "stream_A")
        #expect(destinations[1].configuration.streamKey == "stream_B")
    }
}
