// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RecordingSegment")
struct RecordingSegmentTests {

    @Test("all properties stored correctly")
    func propertiesStored() {
        let segment = RecordingSegment(
            filePath: "/tmp/test.flv",
            format: .flv,
            duration: 30.0,
            fileSize: 1024,
            videoFrameCount: 900,
            audioFrameCount: 600,
            startTimestamp: 0,
            endTimestamp: 30000,
            recordingStarted: 100.0,
            recordingEnded: 130.0
        )
        #expect(segment.filePath == "/tmp/test.flv")
        #expect(segment.format == .flv)
        #expect(segment.duration == 30.0)
        #expect(segment.fileSize == 1024)
        #expect(segment.videoFrameCount == 900)
        #expect(segment.audioFrameCount == 600)
        #expect(segment.startTimestamp == 0)
        #expect(segment.endTimestamp == 30000)
    }

    @Test("duration can be zero for empty segments")
    func zeroDuration() {
        let segment = RecordingSegment(
            filePath: "/tmp/empty.flv",
            format: .flv,
            duration: 0,
            fileSize: 0,
            videoFrameCount: 0,
            audioFrameCount: 0,
            startTimestamp: 0,
            endTimestamp: 0,
            recordingStarted: 100.0,
            recordingEnded: 100.0
        )
        #expect(segment.duration == 0)
        #expect(segment.fileSize == 0)
    }

    @Test("fileSize can be 0 for empty segments")
    func emptyFileSize() {
        let segment = RecordingSegment(
            filePath: "/tmp/empty.flv",
            format: .flv,
            duration: 0,
            fileSize: 0,
            videoFrameCount: 0,
            audioFrameCount: 0,
            startTimestamp: 0,
            endTimestamp: 0,
            recordingStarted: 0,
            recordingEnded: 0
        )
        #expect(segment.fileSize == 0)
    }

    @Test("Sendable compile-time check via generic constraint")
    func sendableCheck() {
        func requireSendable<T: Sendable>(_: T) {}
        let segment = RecordingSegment(
            filePath: "/tmp/test.flv",
            format: .flv,
            duration: 1.0,
            fileSize: 100,
            videoFrameCount: 1,
            audioFrameCount: 1,
            startTimestamp: 0,
            endTimestamp: 1000,
            recordingStarted: 0,
            recordingEnded: 1
        )
        requireSendable(segment)
    }
}
