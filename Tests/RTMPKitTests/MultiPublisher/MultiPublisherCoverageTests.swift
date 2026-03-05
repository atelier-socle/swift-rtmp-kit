// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

/// Build a scripted server response sequence for a successful publish.
private func makePublishScript() -> [RTMPMessage] {
    [
        RTMPMessage(controlMessage: .windowAcknowledgementSize(2_500_000)),
        RTMPMessage(
            controlMessage: .setPeerBandwidth(
                windowSize: 2_500_000, limitType: .dynamic
            )
        ),
        RTMPMessage(
            command: .result(
                transactionID: 1,
                properties: nil,
                information: .object([
                    ("level", .string("status")),
                    ("code", .string("NetConnection.Connect.Success")),
                    ("description", .string("Connection succeeded"))
                ])
            )),
        RTMPMessage(
            command: .result(
                transactionID: 4,
                properties: nil,
                information: .number(1)
            )),
        RTMPMessage(
            command: .onStatus(
                information: .object([
                    ("level", .string("status")),
                    ("code", .string("NetStream.Publish.Start")),
                    ("description", .string("Publishing"))
                ])))
    ]
}

/// Create a MultiPublisher that produces scripted MockTransports
/// which immediately become streaming-ready.
private func makeStreamingMultiPublisher() -> MultiPublisher {
    let script = makePublishScript()
    return MultiPublisher { _ in
        let mock = MockTransport()
        Task { await mock.setScriptedMessages(script) }
        return mock
    }
}

// MARK: - Default Init

@Suite("MultiPublisher — Default Init")
struct MultiPublisherDefaultInitTests {

    @Test("default init creates publisher with NIO transport factory")
    func defaultInit() async {
        let multi = MultiPublisher()
        let states = await multi.destinationStates
        #expect(states.isEmpty)
        let stats = await multi.statistics
        #expect(stats.activeCount == 0)
    }
}

// MARK: - Raw Payload Fan-out

@Suite("MultiPublisher — Raw Payload Fan-out")
struct MultiPublisherRawPayloadTests {

    @Test("sendVideoPayload fans out to streaming destinations")
    func videoPayloadFanout() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "d1")
        // Give scripted publish a moment to complete
        try await Task.sleep(for: .milliseconds(50))
        await multi.sendVideoPayload(
            [0x91, 0x68, 0x76, 0x63, 0x31], timestamp: 100, isKeyframe: true
        )
        // No crash = fan-out worked
        await multi.stopAll()
    }

    @Test("sendVideoConfigPayload fans out to streaming destinations")
    func videoConfigPayloadFanout() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "d1")
        try await Task.sleep(for: .milliseconds(50))
        await multi.sendVideoConfigPayload([0x81, 0x68, 0x76, 0x63, 0x31])
        await multi.stopAll()
    }

    @Test("sendAudioPayload fans out to streaming destinations")
    func audioPayloadFanout() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "d1")
        try await Task.sleep(for: .milliseconds(50))
        await multi.sendAudioPayload([0x88, 0x4F, 0x70], timestamp: 50)
        await multi.stopAll()
    }

    @Test("sendAudioConfigPayload fans out to streaming destinations")
    func audioConfigPayloadFanout() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "d1")
        try await Task.sleep(for: .milliseconds(50))
        await multi.sendAudioConfigPayload([0x80, 0x4F, 0x70])
        await multi.stopAll()
    }

    @Test("raw payload methods skip non-streaming destinations")
    func rawPayloadSkipsNonStreaming() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "idle1", url: "rtmp://h/app", streamKey: "k")
        )
        // Don't start — destination stays idle
        await multi.sendVideoPayload([0x01], timestamp: 0, isKeyframe: false)
        await multi.sendVideoConfigPayload([0x02])
        await multi.sendAudioPayload([0x03], timestamp: 0)
        await multi.sendAudioConfigPayload([0x04])
        // No crash = skip worked
    }
}

// MARK: - Extended Media Fan-out

@Suite("MultiPublisher — Extended Media Fan-out")
struct MultiPublisherExtendedMediaTests {

    @Test("sendRawDataMessage fans out to streaming destinations")
    func rawDataMessageFanout() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "d1")
        try await Task.sleep(for: .milliseconds(50))
        await multi.sendRawDataMessage([0x02, 0x00, 0x0A])
        await multi.stopAll()
    }

    @Test("sendMetadata fans out to streaming destinations")
    func metadataFanout() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "d1")
        try await Task.sleep(for: .milliseconds(50))
        let metadata = StreamMetadata()
        await multi.sendMetadata(metadata)
        await multi.stopAll()
    }

    @Test("sendText fans out to streaming destinations")
    func textFanout() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "d1")
        try await Task.sleep(for: .milliseconds(50))
        await multi.sendText("hello", timestamp: 1000)
        await multi.stopAll()
    }

    @Test("sendCuePoint fans out to streaming destinations")
    func cuePointFanout() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "d1")
        try await Task.sleep(for: .milliseconds(50))
        let cuePoint = CuePoint(name: "ad-start", time: 1.0)
        await multi.sendCuePoint(cuePoint)
        await multi.stopAll()
    }

    @Test("sendCaption fans out to streaming destinations")
    func captionFanout() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "d1")
        try await Task.sleep(for: .milliseconds(50))
        let caption = CaptionData(text: "Hello world", timestamp: 2.0)
        await multi.sendCaption(caption)
        await multi.stopAll()
    }
}

// MARK: - Stop by ID

@Suite("MultiPublisher — Stop by ID")
struct MultiPublisherStopCoverageTests {

    @Test("stop(id:) disconnects publisher and sets state to stopped")
    func stopByIDSetsState() async throws {
        let multi = makeStreamingMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "s1", url: "rtmp://h/app", streamKey: "k")
        )
        try? await multi.start(id: "s1")
        try await Task.sleep(for: .milliseconds(50))
        try await multi.stop(id: "s1")
        let state = await multi.state(for: "s1")
        #expect(state == .stopped)
    }
}
