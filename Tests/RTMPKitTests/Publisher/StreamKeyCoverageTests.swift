// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("StreamKey — IPv6 and Edge Cases")
struct StreamKeyIPv6Tests {

    @Test("Parses IPv6 address with default port")
    func ipv6DefaultPort() throws {
        let key = try StreamKey(url: "rtmp://[::1]/app", streamKey: "test")
        #expect(key.host == "::1")
        #expect(key.port == 1935)
        #expect(key.app == "app")
        #expect(key.key == "test")
    }

    @Test("Parses IPv6 address with custom port")
    func ipv6CustomPort() throws {
        let key = try StreamKey(
            url: "rtmp://[::1]:9999/app", streamKey: "test")
        #expect(key.host == "::1")
        #expect(key.port == 9999)
    }

    @Test("IPv6 with invalid port throws")
    func ipv6InvalidPort() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(
                url: "rtmp://[::1]:99999/app", streamKey: "test")
        }
    }

    @Test("IPv6 without closing bracket throws")
    func ipv6NoBracket() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(url: "rtmp://[::1/app", streamKey: "test")
        }
    }

    @Test("Standard host with invalid port throws")
    func invalidPortNumber() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(
                url: "rtmp://host:70000/app", streamKey: "test")
        }
    }

    @Test("Standard host with non-numeric port throws")
    func nonNumericPort() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(
                url: "rtmp://host:abc/app", streamKey: "test")
        }
    }

    @Test("URL with only scheme throws missing host")
    func missingHostAfterScheme() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(url: "rtmp://", streamKey: "test")
        }
    }

    @Test("Empty host in URL throws")
    func emptyHostInURL() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(url: "rtmp:///app", streamKey: "test")
        }
    }

    @Test("RTMPS uses port 443 by default")
    func rtmpsDefaultPort() throws {
        let key = try StreamKey(
            url: "rtmps://secure.host/app", streamKey: "test")
        #expect(key.port == 443)
        #expect(key.useTLS)
    }

    @Test("Combined URL with IPv6")
    func combinedIPv6() throws {
        let key = try StreamKey(combinedURL: "rtmp://[::1]:1935/app/mykey")
        #expect(key.host == "::1")
        #expect(key.port == 1935)
        #expect(key.app == "app")
        #expect(key.key == "mykey")
    }

    @Test("Port zero throws invalid port")
    func portZeroThrows() {
        #expect(throws: RTMPError.self) {
            _ = try StreamKey(
                url: "rtmp://host:0/app", streamKey: "test")
        }
    }
}
