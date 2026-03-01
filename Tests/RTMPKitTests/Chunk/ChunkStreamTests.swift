// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkStream")
struct ChunkStreamTests {

    // MARK: - Initial State

    @Test("Initial state has all zeros")
    func initialState() {
        let stream = ChunkStream(chunkStreamID: 3)
        #expect(stream.chunkStreamID == 3)
        #expect(stream.lastTimestamp == 0)
        #expect(stream.lastTimestampDelta == 0)
        #expect(stream.lastMessageLength == 0)
        #expect(stream.lastMessageTypeID == 0)
        #expect(stream.lastMessageStreamID == 0)
        #expect(!stream.lastHadExtendedTimestamp)
        #expect(stream.pendingPayload.isEmpty)
        #expect(stream.pendingMessageLength == 0)
    }

    // MARK: - Update From Header

    @Test("Update from fmt 0 header sets all fields")
    func updateFromFmt0() {
        var stream = ChunkStream(chunkStreamID: 3)
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 1000,
            messageLength: 256,
            messageTypeID: 20,
            messageStreamID: 1
        )
        stream.updateFromHeader(header)
        #expect(stream.lastTimestamp == 1000)
        #expect(stream.lastMessageLength == 256)
        #expect(stream.lastMessageTypeID == 20)
        #expect(stream.lastMessageStreamID == 1)
        #expect(!stream.lastHadExtendedTimestamp)
    }

    @Test("Update tracks extended timestamp flag")
    func updateExtendedTimestamp() {
        var stream = ChunkStream(chunkStreamID: 3)
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 0x0100_0000,
            messageLength: 10,
            messageTypeID: 1,
            messageStreamID: 0
        )
        stream.updateFromHeader(header)
        #expect(stream.lastHadExtendedTimestamp)
    }

    @Test("Update delta stores timestamp delta")
    func updateDelta() {
        var stream = ChunkStream(chunkStreamID: 3)
        stream.updateDelta(500)
        #expect(stream.lastTimestampDelta == 500)
    }

    // MARK: - Pending Payload

    @Test("hasPendingMessage is false initially")
    func noPendingInitially() {
        let stream = ChunkStream(chunkStreamID: 3)
        #expect(!stream.hasPendingMessage)
    }

    @Test("hasPendingMessage is true after adding payload")
    func hasPendingAfterAdd() {
        var stream = ChunkStream(chunkStreamID: 3)
        stream.pendingPayload = [0x01, 0x02]
        #expect(stream.hasPendingMessage)
    }

    @Test("clearPending resets payload and length")
    func clearPending() {
        var stream = ChunkStream(chunkStreamID: 3)
        stream.pendingPayload = [0x01, 0x02]
        stream.pendingMessageLength = 100
        stream.pendingTimestamp = 500
        stream.clearPending()
        #expect(stream.pendingPayload.isEmpty)
        #expect(stream.pendingMessageLength == 0)
        #expect(stream.pendingTimestamp == 0)
    }

    // MARK: - Reset

    @Test("Reset clears all state")
    func resetAllState() {
        var stream = ChunkStream(chunkStreamID: 3)
        let header = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 1000,
            messageLength: 256,
            messageTypeID: 20,
            messageStreamID: 1
        )
        stream.updateFromHeader(header)
        stream.updateDelta(500)
        stream.pendingPayload = [0x01, 0x02]
        stream.pendingMessageLength = 100
        stream.reset()
        #expect(stream.lastTimestamp == 0)
        #expect(stream.lastTimestampDelta == 0)
        #expect(stream.lastMessageLength == 0)
        #expect(stream.lastMessageTypeID == 0)
        #expect(stream.lastMessageStreamID == 0)
        #expect(!stream.lastHadExtendedTimestamp)
        #expect(stream.pendingPayload.isEmpty)
        #expect(stream.pendingMessageLength == 0)
    }

    // MARK: - Multiple CSIDs

    @Test("Multiple CSIDs maintain independent state")
    func independentCSIDs() {
        var stream3 = ChunkStream(chunkStreamID: 3)
        var stream4 = ChunkStream(chunkStreamID: 4)
        let header3 = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 100,
            messageLength: 50,
            messageTypeID: 20,
            messageStreamID: 1
        )
        let header4 = ChunkHeader(
            format: .full,
            chunkStreamID: 4,
            timestamp: 200,
            messageLength: 100,
            messageTypeID: 8,
            messageStreamID: 1
        )
        stream3.updateFromHeader(header3)
        stream4.updateFromHeader(header4)
        #expect(stream3.lastTimestamp == 100)
        #expect(stream3.lastMessageTypeID == 20)
        #expect(stream4.lastTimestamp == 200)
        #expect(stream4.lastMessageTypeID == 8)
    }

    // MARK: - Successive Updates

    @Test("Successive updates track latest values")
    func successiveUpdates() {
        var stream = ChunkStream(chunkStreamID: 3)
        let h1 = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 100,
            messageLength: 50,
            messageTypeID: 20,
            messageStreamID: 1
        )
        stream.updateFromHeader(h1)
        #expect(stream.lastTimestamp == 100)
        let h2 = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 200,
            messageLength: 60,
            messageTypeID: 9,
            messageStreamID: 1
        )
        stream.updateFromHeader(h2)
        #expect(stream.lastTimestamp == 200)
        #expect(stream.lastMessageLength == 60)
        #expect(stream.lastMessageTypeID == 9)
    }

    @Test("Extended timestamp flag updates correctly")
    func extendedTimestampFlagUpdates() {
        var stream = ChunkStream(chunkStreamID: 3)
        let h1 = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 0x0100_0000
        )
        stream.updateFromHeader(h1)
        #expect(stream.lastHadExtendedTimestamp)
        let h2 = ChunkHeader(
            format: .full,
            chunkStreamID: 3,
            timestamp: 100
        )
        stream.updateFromHeader(h2)
        #expect(!stream.lastHadExtendedTimestamp)
    }
}
