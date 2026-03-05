// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPServerSession")
struct RTMPServerSessionTests {

    @Test("initial state is .handshaking")
    func initialState() async {
        let session = RTMPServerSession(transport: MockTransport())
        let state = await session.state
        #expect(state == .handshaking)
    }

    @Test("id is a unique UUID")
    func uniqueID() async {
        let s1 = RTMPServerSession(transport: MockTransport())
        let s2 = RTMPServerSession(transport: MockTransport())
        let id1 = await s1.id
        let id2 = await s2.id
        #expect(id1 != id2)
    }

    @Test("connectedAt is stored correctly")
    func connectedAt() async {
        let session = RTMPServerSession(
            transport: MockTransport(),
            connectedAt: 42.5
        )
        let time = await session.connectedAt
        #expect(time == 42.5)
    }

    @Test("bytesReceived starts at 0")
    func zeroBytesReceived() async {
        let session = RTMPServerSession(transport: MockTransport())
        let bytes = await session.bytesReceived
        #expect(bytes == 0)
    }

    @Test("videoFramesReceived starts at 0")
    func zeroVideoFrames() async {
        let session = RTMPServerSession(transport: MockTransport())
        let count = await session.videoFramesReceived
        #expect(count == 0)
    }

    @Test("state transitions: handshaking → connected → publishing")
    func stateTransitions() async {
        let session = RTMPServerSession(transport: MockTransport())
        var state = await session.state
        #expect(state == .handshaking)

        await session.transitionToConnected(appName: "live")
        state = await session.state
        #expect(state == .connected)
        let appName = await session.appName
        #expect(appName == "live")

        await session.transitionToPublishing(streamName: "test_key")
        state = await session.state
        #expect(state == .publishing)
        let streamName = await session.streamName
        #expect(streamName == "test_key")
    }

    @Test("close transitions to .stopped")
    func closeTransition() async {
        let session = RTMPServerSession(transport: MockTransport())
        await session.close()
        let state = await session.state
        #expect(state == .stopped)
    }

    @Test("recordBytesReceived increments")
    func bytesReceivedIncrements() async {
        let session = RTMPServerSession(transport: MockTransport())
        await session.recordBytesReceived(100)
        await session.recordBytesReceived(50)
        let bytes = await session.bytesReceived
        #expect(bytes == 150)
    }

    @Test("recordVideoFrame and recordAudioFrame increment")
    func frameCountsIncrement() async {
        let session = RTMPServerSession(transport: MockTransport())
        await session.recordVideoFrame()
        await session.recordVideoFrame()
        await session.recordAudioFrame()
        let video = await session.videoFramesReceived
        let audio = await session.audioFramesReceived
        #expect(video == 2)
        #expect(audio == 1)
    }
}
