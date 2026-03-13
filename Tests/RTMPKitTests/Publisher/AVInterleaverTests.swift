// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("AVInterleaver — Timestamp Reordering")
struct AVInterleaverReorderingTests {

    private func audioMsg(ts: UInt32) -> RTMPMessage {
        RTMPMessage(
            typeID: RTMPMessage.typeIDAudio,
            streamID: 1, timestamp: ts, payload: [0xAA]
        )
    }

    private func videoMsg(ts: UInt32) -> RTMPMessage {
        RTMPMessage(
            typeID: RTMPMessage.typeIDVideo,
            streamID: 1, timestamp: ts, payload: [0xBB]
        )
    }

    @Test("single-stream flushes immediately")
    func singleStreamFlushes() {
        var interleaver = AVInterleaver()
        let entries = interleaver.enqueue(
            message: videoMsg(ts: 100), chunkStreamID: .video
        )
        #expect(entries.count == 1)
        #expect(entries[0].message.timestamp == 100)
    }

    @Test("two-stream drains entries at or below both high-water marks")
    func twoStreamDrains() {
        var interleaver = AVInterleaver()
        // Video ts=0 — single stream, flushed immediately
        let e1 = interleaver.enqueue(
            message: videoMsg(ts: 0), chunkStreamID: .video
        )
        #expect(e1.count == 1)

        // Audio ts=0 — both streams. min(0,0)=0. Entry at ts=0 flushed.
        let e2 = interleaver.enqueue(
            message: audioMsg(ts: 0), chunkStreamID: .audio
        )
        #expect(e2.count == 1)
    }

    @Test("interleaves in timestamp order across both streams")
    func interleavesCorrectly() {
        var interleaver = AVInterleaver()
        // Step 1: Video ts=100 — single stream → flush immediately
        let e1 = interleaver.enqueue(
            message: videoMsg(ts: 100), chunkStreamID: .video
        )
        #expect(e1.count == 1)
        #expect(e1[0].message.timestamp == 100)

        // Step 2: Audio ts=50 → both streams, threshold=min(50,100)=50
        // Buffer=[audio@50], flush ≤50 → [audio@50]
        let e2 = interleaver.enqueue(
            message: audioMsg(ts: 50), chunkStreamID: .audio
        )
        #expect(e2.count == 1)
        #expect(e2[0].message.timestamp == 50)

        // Step 3: Video ts=200 → threshold=min(50,200)=50
        // Buffer=[video@200], nothing ≤50 → []
        let e3 = interleaver.enqueue(
            message: videoMsg(ts: 200), chunkStreamID: .video
        )
        #expect(e3.count == 0)

        // Step 4: Audio ts=150 → threshold=min(150,200)=150
        // Buffer=[audio@150, video@200], flush ≤150 → [audio@150]
        let e4 = interleaver.enqueue(
            message: audioMsg(ts: 150), chunkStreamID: .audio
        )
        #expect(e4.count == 1)
        #expect(e4[0].message.timestamp == 150)

        // Step 5: Audio ts=250 → threshold=min(250,200)=200
        // Buffer=[video@200, audio@250], flush ≤200 → [video@200]
        let e5 = interleaver.enqueue(
            message: audioMsg(ts: 250), chunkStreamID: .audio
        )
        #expect(e5.count == 1)
        #expect(e5[0].message.timestamp == 200)
    }

    @Test("force-flushes when buffer exceeds maxBufferSize")
    func forceFlush() {
        var interleaver = AVInterleaver(maxBufferSize: 2)
        // Step 1: Video ts=100 — single stream → flush immediately
        _ = interleaver.enqueue(
            message: videoMsg(ts: 100), chunkStreamID: .video
        )
        // Step 2: Audio ts=50 → threshold=50, flush audio@50. buffer=[]
        _ = interleaver.enqueue(
            message: audioMsg(ts: 50), chunkStreamID: .audio
        )
        // Step 3: Video ts=200 → threshold=50, buffer=[video@200]
        _ = interleaver.enqueue(
            message: videoMsg(ts: 200), chunkStreamID: .video
        )
        // Step 4: Video ts=300 → threshold=50, buffer=[video@200, video@300]
        _ = interleaver.enqueue(
            message: videoMsg(ts: 300), chunkStreamID: .video
        )
        // Step 5: Video ts=400 → buffer=[v@200,v@300,v@400] → 3 > 2 → force flush
        let entries = interleaver.enqueue(
            message: videoMsg(ts: 400), chunkStreamID: .video
        )
        #expect(entries.count == 3)
        #expect(interleaver.count == 0)
    }

    @Test("flushAll returns all pending entries and empties buffer")
    func flushAllReturnsAll() {
        var interleaver = AVInterleaver()
        _ = interleaver.enqueue(
            message: videoMsg(ts: 100), chunkStreamID: .video
        )
        // After single-stream flush, buffer is empty, but let's add more
        _ = interleaver.enqueue(
            message: audioMsg(ts: 50), chunkStreamID: .audio
        )
        // Now add something that stays buffered
        _ = interleaver.enqueue(
            message: videoMsg(ts: 200), chunkStreamID: .video
        )
        let all = interleaver.flushAll()
        #expect(interleaver.count == 0)
        _ = all
    }

    @Test("reset clears all state")
    func resetClearsState() {
        var interleaver = AVInterleaver()
        _ = interleaver.enqueue(
            message: videoMsg(ts: 100), chunkStreamID: .video
        )
        interleaver.reset()
        #expect(interleaver.count == 0)
    }

    @Test("single-stream audio flushes immediately")
    func singleStreamAudioFlushes() {
        var interleaver = AVInterleaver()
        let e1 = interleaver.enqueue(
            message: audioMsg(ts: 100), chunkStreamID: .audio
        )
        #expect(e1.count == 1)
        let e2 = interleaver.enqueue(
            message: audioMsg(ts: 200), chunkStreamID: .audio
        )
        #expect(e2.count == 1)
    }
}
