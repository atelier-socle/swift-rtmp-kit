// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPServerAccessControl")
struct RTMPServerAccessControlTests {

    @Test("isAllowed returns true for unknown IP with empty lists")
    func allowedByDefault() async {
        let ac = RTMPServerAccessControl()
        let result = await ac.isAllowed("192.168.1.1")
        #expect(result)
    }

    @Test("isAllowed returns false for IP on blocklist")
    func blockedByBlocklist() async {
        let ac = RTMPServerAccessControl(blocklist: ["10.0.0.1"])
        let result = await ac.isAllowed("10.0.0.1")
        #expect(!result)
    }

    @Test("addToAllowlist then isAllowed returns true even if on blocklist")
    func allowlistOverridesBlocklist() async {
        let ac = RTMPServerAccessControl(blocklist: ["10.0.0.1"])
        await ac.addToAllowlist("10.0.0.1")
        let result = await ac.isAllowed("10.0.0.1")
        #expect(result)
    }

    @Test("addToBlocklist then isAllowed returns false")
    func dynamicBlock() async {
        let ac = RTMPServerAccessControl()
        await ac.addToBlocklist("1.2.3.4")
        let result = await ac.isAllowed("1.2.3.4")
        #expect(!result)
    }

    @Test("removeFromBlocklist then isAllowed returns true")
    func removeBlock() async {
        let ac = RTMPServerAccessControl(blocklist: ["1.2.3.4"])
        await ac.removeFromBlocklist("1.2.3.4")
        let result = await ac.isAllowed("1.2.3.4")
        #expect(result)
    }

    @Test("ban with future expiry makes isAllowed return false")
    func temporaryBan() async {
        let ac = RTMPServerAccessControl()
        await ac.ban("5.6.7.8", duration: 300)
        let result = await ac.isAllowed("5.6.7.8")
        #expect(!result)
    }

    @Test("ban with very short duration expires and allows")
    func expiredBan() async throws {
        let ac = RTMPServerAccessControl()
        await ac.ban("5.6.7.8", duration: 0.001)
        try await Task.sleep(nanoseconds: 5_000_000)  // 5ms
        let result = await ac.isAllowed("5.6.7.8")
        #expect(result)
    }

    @Test("unban lifts temporary ban immediately")
    func unban() async {
        let ac = RTMPServerAccessControl()
        await ac.ban("5.6.7.8", duration: 300)
        await ac.unban("5.6.7.8")
        let result = await ac.isAllowed("5.6.7.8")
        #expect(result)
    }

    @Test("non-empty allowlist denies unknown IP")
    func allowlistDeniesUnknown() async {
        let ac = RTMPServerAccessControl(allowlist: ["10.0.0.1"])
        let result = await ac.isAllowed("10.0.0.2")
        #expect(!result)
    }

    @Test("non-empty allowlist allows known IP")
    func allowlistAllowsKnown() async {
        let ac = RTMPServerAccessControl(allowlist: ["10.0.0.1"])
        let result = await ac.isAllowed("10.0.0.1")
        #expect(result)
    }
}
