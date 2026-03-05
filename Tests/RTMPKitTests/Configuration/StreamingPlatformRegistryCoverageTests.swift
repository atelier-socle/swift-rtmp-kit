// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("StreamingPlatformRegistry — Alias Lookup")
struct StreamingPlatformRegistryCoverageTests {

    @Test("configuration for 'x' alias returns twitter config")
    func xAliasReturnsTwitter() {
        let config = StreamingPlatformRegistry.configuration(
            platform: "x", streamKey: "test_key"
        )
        #expect(config != nil)
        #expect(config?.preset?.platformName == "twitter")
    }
}
