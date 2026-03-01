// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("TwitchIngestServer")
struct TwitchIngestServerTests {

    @Test("auto rawValue is live.twitch.tv")
    func autoRawValue() {
        #expect(TwitchIngestServer.auto.rawValue == "live.twitch.tv")
    }

    @Test("hostname property matches rawValue")
    func hostnameMatchesRawValue() {
        for server in TwitchIngestServer.allCases {
            #expect(server.hostname == server.rawValue)
        }
    }

    @Test("CaseIterable has at least 7 cases")
    func caseIterableCount() {
        #expect(TwitchIngestServer.allCases.count >= 7)
    }

    @Test("all cases have non-empty rawValue")
    func nonEmptyRawValues() {
        for server in TwitchIngestServer.allCases {
            #expect(!server.rawValue.isEmpty)
        }
    }

    @Test("each case has unique rawValue")
    func uniqueRawValues() {
        let values = TwitchIngestServer.allCases.map(\.rawValue)
        let unique = Set(values)
        #expect(values.count == unique.count)
    }

    @Test("usEast hostname contains expected domain")
    func usEastHostname() {
        #expect(TwitchIngestServer.usEast.hostname.contains("iad05"))
    }

    @Test("rawValue init roundtrip")
    func rawValueRoundtrip() {
        for server in TwitchIngestServer.allCases {
            let roundtripped = TwitchIngestServer(rawValue: server.rawValue)
            #expect(roundtripped == server)
        }
    }

    @Test("regional servers use contribute domain")
    func regionalContributeDomain() {
        let regional: [TwitchIngestServer] = [
            .usEast, .usWest, .europe, .asia, .southAmerica, .australia
        ]
        for server in regional {
            #expect(server.hostname.contains("contribute.live-video.net"))
        }
    }
}
