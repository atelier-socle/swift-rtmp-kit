// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPStreamRelay")
struct RTMPStreamRelayTests {

    private func makeRelay(
        destinations: [RTMPStreamRelay.RelayDestination]
    ) -> RTMPStreamRelay {
        RTMPStreamRelay(
            destinations: destinations,
            transportFactory: { _ in
                MockTransport(messages: [], connected: true)
            }
        )
    }

    private func twitchDest() -> RTMPStreamRelay.RelayDestination {
        .init(
            id: "twitch",
            configuration: .twitch(streamKey: "live_xxx")
        )
    }

    private func youtubeDest() -> RTMPStreamRelay.RelayDestination {
        .init(
            id: "youtube",
            configuration: .youtube(streamKey: "yyyy-yyyy")
        )
    }

    @Test("Initial state is .idle")
    func initialState() async {
        let relay = makeRelay(destinations: [twitchDest()])
        let state = await relay.state
        #expect(state == .idle)
    }

    @Test("start() transitions to .relaying")
    func startTransition() async throws {
        let relay = makeRelay(destinations: [twitchDest()])
        try await relay.start()
        let state = await relay.state
        #expect(state == .relaying)
    }

    @Test("stop() transitions to .stopped")
    func stopTransition() async throws {
        let relay = makeRelay(destinations: [twitchDest()])
        try await relay.start()
        await relay.stop()
        let state = await relay.state
        #expect(state == .stopped)
    }

    @Test("relayVideo increments framesRelayed")
    func relayVideoIncrementsFrames() async throws {
        let relay = makeRelay(destinations: [twitchDest()])
        try await relay.start()
        await relay.relayVideo(
            [0x17, 0x01, 0x00], timestamp: 0, isKeyframe: true
        )
        let count = await relay.framesRelayed
        #expect(count == 1)
    }

    @Test("relayAudio increments framesRelayed")
    func relayAudioIncrementsFrames() async throws {
        let relay = makeRelay(destinations: [twitchDest()])
        try await relay.start()
        await relay.relayAudio([0xAF, 0x01], timestamp: 0)
        let count = await relay.framesRelayed
        #expect(count == 1)
    }

    @Test("framesRelayed counts both video and audio")
    func framesRelayedCountsBoth() async throws {
        let relay = makeRelay(
            destinations: [twitchDest(), youtubeDest()]
        )
        try await relay.start()
        await relay.relayVideo(
            [0x17, 0x01], timestamp: 0, isKeyframe: true
        )
        await relay.relayAudio([0xAF, 0x01], timestamp: 0)
        let count = await relay.framesRelayed
        #expect(count == 2)
    }

    @Test("Relay with zero destinations: no crash")
    func zeroDestinations() async throws {
        let relay = makeRelay(destinations: [])
        try await relay.start()
        await relay.relayVideo(
            [0x17, 0x01], timestamp: 0, isKeyframe: true
        )
        let count = await relay.framesRelayed
        #expect(count == 1)
        let state = await relay.state
        #expect(state == .relaying)
    }

    @Test("relayVideo while idle is a no-op")
    func relayWhileIdle() async {
        let relay = makeRelay(destinations: [twitchDest()])
        await relay.relayVideo(
            [0x17, 0x01], timestamp: 0, isKeyframe: true
        )
        let count = await relay.framesRelayed
        #expect(count == 0)
    }
}
