// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("TimedMetadata")
struct TimedMetadataTests {

    @Test("Text messageName is onTextData")
    func textMessageName() {
        let tm = TimedMetadata.text("hello", timestamp: 100)
        #expect(tm.messageName == "onTextData")
    }

    @Test("CuePoint messageName is onCuePoint")
    func cuePointMessageName() {
        let cp = CuePoint(name: "test", time: 0)
        let tm = TimedMetadata.cuePoint(cp)
        #expect(tm.messageName == "onCuePoint")
    }

    @Test("Caption messageName is onCaptionInfo")
    func captionMessageName() {
        let cd = CaptionData(text: "hi", timestamp: 0)
        let tm = TimedMetadata.caption(cd)
        #expect(tm.messageName == "onCaptionInfo")
    }

    @Test("Text timestamp")
    func textTimestamp() {
        let tm = TimedMetadata.text("hello", timestamp: 42.5)
        #expect(tm.timestamp == 42.5)
    }

    @Test("CuePoint timestamp")
    func cuePointTimestamp() {
        let cp = CuePoint(name: "test", time: 1500)
        let tm = TimedMetadata.cuePoint(cp)
        #expect(tm.timestamp == 1500)
    }

    @Test("Caption timestamp")
    func captionTimestamp() {
        let cd = CaptionData(text: "hi", timestamp: 3000)
        let tm = TimedMetadata.caption(cd)
        #expect(tm.timestamp == 3000)
    }

    @Test("Text toAMF0Payload creates object with text and language")
    func textPayload() {
        let tm = TimedMetadata.text("greeting", timestamp: 0)
        let payload = tm.toAMF0Payload()
        guard let props = payload.objectProperties else {
            Issue.record("Expected object")
            return
        }
        let dict = Dictionary(props, uniquingKeysWith: { _, b in b })
        #expect(dict["text"] == .string("greeting"))
        #expect(dict["language"] == .string("en"))
    }

    @Test("CuePoint toAMF0Payload delegates to CuePoint.toAMF0Object")
    func cuePointPayload() {
        let cp = CuePoint(name: "scene", time: 5000, type: .navigation)
        let tm = TimedMetadata.cuePoint(cp)
        let payload = tm.toAMF0Payload()
        #expect(payload == cp.toAMF0Object())
    }

    @Test("Caption toAMF0Payload delegates to CaptionData.toAMF0Object")
    func captionPayload() {
        let cd = CaptionData(text: "sub", timestamp: 7000)
        let tm = TimedMetadata.caption(cd)
        let payload = tm.toAMF0Payload()
        #expect(payload == cd.toAMF0Object())
    }
}
