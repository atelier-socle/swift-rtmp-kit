// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("PublishDestination")
struct PublishDestinationTests {

    @Test("full init stores id and configuration")
    func fullInit() {
        let config = RTMPConfiguration(
            url: "rtmp://server/app", streamKey: "key123"
        )
        let dest = PublishDestination(id: "dest-1", configuration: config)
        #expect(dest.id == "dest-1")
        #expect(dest.configuration.url == "rtmp://server/app")
        #expect(dest.configuration.streamKey == "key123")
    }

    @Test("convenience init creates valid configuration")
    func convenienceInit() {
        let dest = PublishDestination(
            id: "twitch", url: "rtmp://live.twitch.tv/app", streamKey: "live_key"
        )
        #expect(dest.id == "twitch")
        #expect(dest.configuration.url == "rtmp://live.twitch.tv/app")
        #expect(dest.configuration.streamKey == "live_key")
    }

    @Test("two destinations with different IDs are independent")
    func differentIDsIndependent() {
        let d1 = PublishDestination(
            id: "dest-a", url: "rtmp://a/app", streamKey: "ka"
        )
        let d2 = PublishDestination(
            id: "dest-b", url: "rtmp://b/app", streamKey: "kb"
        )
        #expect(d1.id != d2.id)
        #expect(d1.configuration.url != d2.configuration.url)
    }

    @Test("id is stored verbatim")
    func idStoredVerbatim() {
        let dest = PublishDestination(
            id: "My-Custom_ID.123", url: "rtmp://s/app", streamKey: "k"
        )
        #expect(dest.id == "My-Custom_ID.123")
    }
}
