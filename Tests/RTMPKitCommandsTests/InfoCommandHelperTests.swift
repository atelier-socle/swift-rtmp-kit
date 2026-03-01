// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import RTMPKit
import Testing

@testable import RTMPKitCommands

@Suite("InfoCommand — parseURL()")
struct InfoCommandParseURLTests {

    @Test("rtmp URL with app")
    func rtmpWithApp() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app"
        ])
        let parsed = cmd.parseURL("rtmp://server/app")
        #expect(parsed.host == "server")
        #expect(parsed.port == 1935)
        #expect(parsed.useTLS == false)
        #expect(parsed.app == "app")
    }

    @Test("rtmps URL defaults to port 443")
    func rtmpsDefaultPort() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmps://live.twitch.tv/app"
        ])
        let parsed = cmd.parseURL("rtmps://live.twitch.tv/app")
        #expect(parsed.host == "live.twitch.tv")
        #expect(parsed.port == 443)
        #expect(parsed.useTLS == true)
        #expect(parsed.app == "app")
    }

    @Test("rtmp URL with custom port")
    func rtmpCustomPort() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://192.168.1.1:1935/live"
        ])
        let parsed = cmd.parseURL("rtmp://192.168.1.1:1935/live")
        #expect(parsed.host == "192.168.1.1")
        #expect(parsed.port == 1935)
        #expect(parsed.app == "live")
    }

    @Test("rtmp URL with non-standard port")
    func rtmpNonStandardPort() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server:8080/app"
        ])
        let parsed = cmd.parseURL("rtmp://server:8080/app")
        #expect(parsed.host == "server")
        #expect(parsed.port == 8080)
    }

    @Test("rtmps URL with custom port")
    func rtmpsCustomPort() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmps://server:8443/live"
        ])
        let parsed = cmd.parseURL("rtmps://server:8443/live")
        #expect(parsed.host == "server")
        #expect(parsed.port == 8443)
        #expect(parsed.useTLS == true)
    }

    @Test("URL without app path")
    func noAppPath() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server"
        ])
        let parsed = cmd.parseURL("rtmp://server")
        #expect(parsed.host == "server")
        #expect(parsed.app == "")
    }

    @Test("URL with subpath in app")
    func subpathApp() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/live/subpath"
        ])
        let parsed = cmd.parseURL("rtmp://server/live/subpath")
        #expect(parsed.host == "server")
        #expect(parsed.app == "live/subpath")
    }

    @Test("URL with invalid port falls back to default")
    func invalidPort() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server:abc/app"
        ])
        let parsed = cmd.parseURL("rtmp://server:abc/app")
        #expect(parsed.host == "server")
        #expect(parsed.port == 1935)
    }

    @Test("URL without scheme prefix")
    func noScheme() throws {
        let cmd = try InfoCommand.parse([
            "--url", "server/app"
        ])
        let parsed = cmd.parseURL("server/app")
        #expect(parsed.host == "server")
        #expect(parsed.useTLS == false)
        #expect(parsed.app == "app")
    }
}

@Suite("InfoCommand — printInfo()")
struct InfoCommandPrintInfoTests {

    @Test("printInfo produces output without crash")
    func printInfoProducesOutput() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app"
        ])
        var stats = ConnectionStatistics()
        stats.bytesSent = 1024
        stats.bytesReceived = 2048
        cmd.printInfo(stats: stats)
    }

    @Test("printInfo with RTT value")
    func printInfoWithRTT() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app"
        ])
        var stats = ConnectionStatistics()
        stats.roundTripTime = 0.025
        cmd.printInfo(stats: stats)
    }

    @Test("printInfo with RTMPS url")
    func printInfoRTMPS() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmps://live.twitch.tv/app"
        ])
        let stats = ConnectionStatistics()
        cmd.printInfo(stats: stats)
    }
}

@Suite("InfoCommand — printJSON()")
struct InfoCommandPrintJSONTests {

    @Test("printJSON produces output without crash")
    func printJSONProducesOutput() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmp://server/app"
        ])
        var stats = ConnectionStatistics()
        stats.bytesSent = 512
        stats.bytesReceived = 1024
        cmd.printJSON(stats: stats)
    }

    @Test("printJSON with RTMPS url")
    func printJSONRTMPS() throws {
        let cmd = try InfoCommand.parse([
            "--url", "rtmps://live.twitch.tv/app"
        ])
        let stats = ConnectionStatistics()
        cmd.printJSON(stats: stats)
    }
}
