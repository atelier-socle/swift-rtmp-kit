// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPKit Core")
struct RTMPKitCoreTests {
    @Test("Version is set")
    func versionIsSet() {
        #expect(RTMPKitVersion.version == "0.2.0")
    }
}
