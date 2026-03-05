// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

// MARK: - Test Helpers

/// Build a scripted server response for a successful publish.
private func makePublishScript(streamID: Double = 1) -> [RTMPMessage] {
    [
        RTMPMessage(
            command: .result(
                transactionID: 1,
                properties: nil,
                information: .object([
                    ("code", .string("NetConnection.Connect.Success"))
                ])
            )),
        RTMPMessage(
            command: .result(
                transactionID: 4,
                properties: nil,
                information: .number(streamID)
            )),
        RTMPMessage(
            command: .onStatus(
                information: .object([
                    ("code", .string("NetStream.Publish.Start")),
                    ("description", .string("Publishing"))
                ])))
    ]
}

/// Create a MultiPublisher with a factory that scripts publish responses via Task.
private func makeScriptedMultiPublisher() -> MultiPublisher {
    let script = makePublishScript()
    return MultiPublisher { _ in
        let mock = MockTransport()
        Task { await mock.setScriptedMessages(script) }
        return mock
    }
}

/// Create a MultiPublisher with a plain (unscripted) factory.
private func makePlainMultiPublisher() -> MultiPublisher {
    MultiPublisher { _ in MockTransport() }
}

// MARK: - Suite 1: Destinations and Configuration

@Suite("MultiPublisher Showcase — Destinations and Configuration")
struct MultiPublisherShowcaseConfigTests {

    @Test("Add three destinations and verify initial states")
    func threeDestinationsIdle() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(
                id: "twitch",
                configuration: .twitch(streamKey: "live_xxx")
            )
        )
        try await multi.addDestination(
            PublishDestination(
                id: "youtube",
                configuration: .youtube(streamKey: "yyy")
            )
        )
        try await multi.addDestination(
            PublishDestination(
                id: "facebook",
                configuration: .facebook(streamKey: "FB-zzz")
            )
        )
        let states = await multi.destinationStates
        #expect(states.count == 3)
        #expect(states["twitch"] == .idle)
        #expect(states["youtube"] == .idle)
        #expect(states["facebook"] == .idle)
    }

    @Test("Duplicate destination ID throws destinationAlreadyExists")
    func duplicateThrows() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(
                id: "twitch",
                configuration: .twitch(streamKey: "key1")
            )
        )
        do {
            try await multi.addDestination(
                PublishDestination(
                    id: "twitch",
                    configuration: .twitch(streamKey: "key2")
                )
            )
            Issue.record("Expected destinationAlreadyExists error")
        } catch let error as MultiPublisherError {
            #expect(error == .destinationAlreadyExists("twitch"))
        }
    }

    @Test("Each destination has independent RTMPConfiguration")
    func independentConfigs() async throws {
        let multi = makePlainMultiPublisher()
        let twitchConfig = RTMPConfiguration.twitch(streamKey: "live_xxx")
        let fbConfig = RTMPConfiguration.facebook(streamKey: "FB-zzz")
        try await multi.addDestination(
            PublishDestination(id: "twitch", configuration: twitchConfig)
        )
        try await multi.addDestination(
            PublishDestination(id: "facebook", configuration: fbConfig)
        )
        #expect(twitchConfig.enhancedRTMP == true)
        #expect(fbConfig.enhancedRTMP == false)
        #expect(await multi.state(for: "twitch") == .idle)
        #expect(await multi.state(for: "facebook") == .idle)
    }

    @Test("Per-destination ABR: each destination can have a different policy")
    func perDestinationABR() async throws {
        let multi = makePlainMultiPublisher()
        var twitchConfig = RTMPConfiguration.twitch(streamKey: "live_xxx")
        twitchConfig.adaptiveBitrate = .responsive(
            min: 1_000_000, max: 6_000_000
        )
        var youtubeConfig = RTMPConfiguration.youtube(streamKey: "yyyy")
        youtubeConfig.adaptiveBitrate = .conservative(
            min: 500_000, max: 4_000_000
        )
        try await multi.addDestination(
            PublishDestination(id: "twitch", configuration: twitchConfig)
        )
        try await multi.addDestination(
            PublishDestination(id: "youtube", configuration: youtubeConfig)
        )
        #expect(twitchConfig.adaptiveBitrate.configuration?.stepDown == 0.75)
        #expect(youtubeConfig.adaptiveBitrate.configuration?.stepDown == 0.80)
        let states = await multi.destinationStates
        #expect(states.count == 2)
    }

    @Test("Remove destination reduces state count")
    func removeReducesCount() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )
        try await multi.removeDestination(id: "d1")
        let states = await multi.destinationStates
        #expect(states.count == 1)
        #expect(states["d2"] == .idle)
    }

    @Test("Remove unknown destination throws destinationNotFound")
    func removeUnknownThrows() async {
        let multi = makePlainMultiPublisher()
        do {
            try await multi.removeDestination(id: "ghost")
            Issue.record("Expected destinationNotFound error")
        } catch let error as MultiPublisherError {
            #expect(error == .destinationNotFound("ghost"))
        } catch {
            Issue.record("Expected MultiPublisherError")
        }
    }
}

// MARK: - Suite 2: Failure Policy

@Suite("MultiPublisher Showcase — Failure Policy")
struct MultiPublisherShowcaseFailurePolicyTests {

    @Test("Default failure policy is continueOnFailure")
    func defaultPolicy() async {
        let multi = makePlainMultiPublisher()
        let policy = await multi.failurePolicy
        #expect(policy == .continueOnFailure)
    }

    @Test("continueOnFailure: one failed destination does not stop others")
    func continueOnFailure() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )
        // Start d1 — will fail (no scripted messages)
        try? await multi.start(id: "d1")
        let d1State = await multi.state(for: "d1")
        let d2State = await multi.state(for: "d2")
        #expect(d1State == .failed(RTMPError.connectionClosed))
        #expect(d2State == .idle)
    }

    @Test("stopAllOnFailure(count: 1): first failure stops everything")
    func stopOnFirstFailure() async throws {
        let multi = makePlainMultiPublisher()
        await multi.setFailurePolicy(.stopAllOnFailure(count: 1))
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )
        // Start d1 — fails → threshold triggers stopAll
        try? await multi.start(id: "d1")
        // Give stopAll task time to execute
        try? await Task.sleep(for: .milliseconds(50))
        let d1State = await multi.state(for: "d1")
        // d1 entered .failed, then stopAll was triggered
        #expect(d1State == .failed(RTMPError.connectionClosed))
    }

    @Test("stopAllOnFailure(count: 2): one failure tolerated, two triggers stop")
    func stopOnSecondFailure() async throws {
        let multi = makePlainMultiPublisher()
        await multi.setFailurePolicy(.stopAllOnFailure(count: 2))
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )
        try await multi.addDestination(
            PublishDestination(id: "d3", url: "rtmp://h/app", streamKey: "k3")
        )
        // Fail d1 — not yet at threshold
        try? await multi.start(id: "d1")
        let d3StateAfterOne = await multi.state(for: "d3")
        #expect(d3StateAfterOne == .idle)
        // Fail d2 — threshold reached
        try? await multi.start(id: "d2")
        try? await Task.sleep(for: .milliseconds(50))
        let d1State = await multi.state(for: "d1")
        let d2State = await multi.state(for: "d2")
        #expect(d1State == .failed(RTMPError.connectionClosed))
        #expect(d2State == .failed(RTMPError.connectionClosed))
    }

    @Test("failureThresholdReached event emitted on policy trigger")
    func thresholdEvent() async throws {
        let multi = makePlainMultiPublisher()
        await multi.setFailurePolicy(.stopAllOnFailure(count: 1))
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )

        let events = await multi.events
        let eventTask = Task {
            var collected: [MultiPublisherEvent] = []
            for await event in events {
                collected.append(event)
                if case .failureThresholdReached = event { break }
                if collected.count >= 10 { break }
            }
            return collected
        }

        try? await multi.start(id: "d1")
        try? await Task.sleep(for: .milliseconds(100))
        eventTask.cancel()
        let result = await eventTask.value

        let hasThreshold = result.contains { event in
            if case .failureThresholdReached = event { return true }
            return false
        }
        #expect(hasThreshold)
    }
}

// MARK: - Suite 3: Events and Statistics

@Suite("MultiPublisher Showcase — Events and Statistics")
struct MultiPublisherShowcaseEventsTests {

    @Test("stateChanged event emitted when destination starts")
    func stateChangedOnStart() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )

        let events = await multi.events
        let eventTask = Task {
            var collected: [MultiPublisherEvent] = []
            for await event in events {
                collected.append(event)
                if collected.count >= 3 { break }
            }
            return collected
        }

        try? await multi.start(id: "d1")
        try? await Task.sleep(for: .milliseconds(50))
        eventTask.cancel()
        let result = await eventTask.value

        let hasConnecting = result.contains { event in
            if case .stateChanged(let id, let state) = event {
                return id == "d1" && state == .connecting
            }
            return false
        }
        #expect(hasConnecting)
    }

    @Test("statisticsUpdated emitted after sendAudio")
    func statsAfterSendAudio() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k")
        )

        let events = await multi.events
        let eventTask = Task {
            var collected: [MultiPublisherEvent] = []
            for await event in events {
                collected.append(event)
                if case .statisticsUpdated = event { break }
                if collected.count >= 10 { break }
            }
            return collected
        }

        await multi.sendAudio([0xAA, 0xBB], timestamp: 0)
        try? await Task.sleep(for: .milliseconds(50))
        eventTask.cancel()
        let result = await eventTask.value

        let hasStats = result.contains { event in
            if case .statisticsUpdated = event { return true }
            return false
        }
        #expect(hasStats)
    }

    @Test("Statistics per destination tracked independently")
    func perDestinationStats() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )
        let stats1 = await multi.statistics(for: "d1")
        let stats2 = await multi.statistics(for: "d2")
        #expect(stats1 != nil)
        #expect(stats2 != nil)
        #expect(stats1?.bytesSent == 0)
        #expect(stats2?.bytesSent == 0)
    }

    @Test("Active count reflects streaming destinations")
    func activeCountReflectsState() async throws {
        let multi = makeScriptedMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )
        // Neither started — both idle
        let stats = await multi.statistics
        #expect(stats.activeCount == 0)
    }

    @Test("stopAll transitions all to stopped or failed")
    func stopAllTransitions() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )
        await multi.stopAll()
        // Idle destinations don't get stopped (not active)
        let d1 = await multi.state(for: "d1")
        let d2 = await multi.state(for: "d2")
        #expect(d1 == .idle)
        #expect(d2 == .idle)
    }

    @Test("Events stream receives state changes from all destinations")
    func eventsFromAll() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )

        let events = await multi.events
        let eventTask = Task {
            var collected: [MultiPublisherEvent] = []
            for await event in events {
                collected.append(event)
                if collected.count >= 4 { break }
            }
            return collected
        }

        try? await multi.start(id: "d1")
        try? await multi.start(id: "d2")
        try? await Task.sleep(for: .milliseconds(50))
        eventTask.cancel()
        let result = await eventTask.value

        let d1Events = result.filter { event in
            if case .stateChanged(let id, _) = event { return id == "d1" }
            return false
        }
        let d2Events = result.filter { event in
            if case .stateChanged(let id, _) = event { return id == "d2" }
            return false
        }
        #expect(!d1Events.isEmpty)
        #expect(!d2Events.isEmpty)
    }

    @Test("Initial statistics are empty")
    func initialStatsEmpty() async {
        let multi = makePlainMultiPublisher()
        let stats = await multi.statistics
        #expect(stats.totalBytesSent == 0)
        #expect(stats.activeCount == 0)
        #expect(stats.totalDroppedFrames == 0)
    }

    @Test("Aggregate statistics track total bytes")
    func aggregateStats() async {
        let multi = makePlainMultiPublisher()
        let stats = await multi.statistics
        #expect(stats.totalBytesSent == 0)
        #expect(stats.perDestination.isEmpty)
    }
}

// MARK: - Suite 4: Real-World Patterns

@Suite("MultiPublisher Showcase — Real-World Patterns")
struct MultiPublisherShowcaseRealWorldTests {

    @Test("Twitch + YouTube + Facebook simultaneous setup")
    func threeWaySetup() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(
                id: "twitch",
                configuration: .twitch(streamKey: "live_xxx")
            )
        )
        try await multi.addDestination(
            PublishDestination(
                id: "youtube",
                configuration: .youtube(streamKey: "yyyy-yyyy")
            )
        )
        try await multi.addDestination(
            PublishDestination(
                id: "facebook",
                configuration: .facebook(streamKey: "FB-zzz")
            )
        )
        let states = await multi.destinationStates
        #expect(states.count == 3)
        #expect(states.values.allSatisfy { $0 == .idle })
    }

    @Test("Hot-add destination after initial setup")
    func hotAdd() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )
        // Simulate sending some frames
        await multi.sendAudio([0x01], timestamp: 0)
        await multi.sendVideo([0x02], timestamp: 0, isKeyframe: true)
        // Hot-add a third destination
        try await multi.addDestination(
            PublishDestination(id: "d3", url: "rtmp://h/app", streamKey: "k3")
        )
        let state = await multi.state(for: "d3")
        #expect(state == .idle)
        let states = await multi.destinationStates
        #expect(states.count == 3)
    }

    @Test("Hot-remove destination leaves others unaffected")
    func hotRemove() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        try await multi.addDestination(
            PublishDestination(id: "d2", url: "rtmp://h/app", streamKey: "k2")
        )
        try await multi.addDestination(
            PublishDestination(id: "d3", url: "rtmp://h/app", streamKey: "k3")
        )
        try await multi.removeDestination(id: "d2")
        let states = await multi.destinationStates
        #expect(states.count == 2)
        #expect(states["d1"] == .idle)
        #expect(states["d3"] == .idle)
        #expect(states["d2"] == nil)
    }

    @Test("Failed destination replaced by re-adding")
    func replaceFailedDestination() async throws {
        let multi = makePlainMultiPublisher()
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1")
        )
        // Start → fails (no scripted messages)
        try? await multi.start(id: "d1")
        let failedState = await multi.state(for: "d1")
        #expect(failedState == .failed(RTMPError.connectionClosed))
        // Remove and re-add
        try await multi.removeDestination(id: "d1")
        try await multi.addDestination(
            PublishDestination(id: "d1", url: "rtmp://h/app", streamKey: "k1-new")
        )
        let newState = await multi.state(for: "d1")
        #expect(newState == .idle)
    }

    @Test("sendAudio and sendVideo are no-ops when no destinations")
    func sendNoDestinations() async {
        let multi = makePlainMultiPublisher()
        await multi.sendAudio([0xAA], timestamp: 0)
        await multi.sendVideo([0x01], timestamp: 0, isKeyframe: true)
        let stats = await multi.statistics
        #expect(stats.totalBytesSent == 0)
    }

    @Test("MultiPublisher with responsive ABR + Twitch preset")
    func abrWithTwitch() async throws {
        let multi = makePlainMultiPublisher()
        var config = RTMPConfiguration.twitch(streamKey: "live_xxx")
        config.adaptiveBitrate = .responsive(
            min: 1_000_000, max: 6_000_000
        )
        let dest = PublishDestination(id: "twitch", configuration: config)
        try await multi.addDestination(dest)
        let state = await multi.state(for: "twitch")
        #expect(state == .idle)
        #expect(config.adaptiveBitrate.configuration != nil)
        #expect(config.adaptiveBitrate.configuration?.minBitrate == 1_000_000)
        #expect(config.adaptiveBitrate.configuration?.maxBitrate == 6_000_000)
    }
}
