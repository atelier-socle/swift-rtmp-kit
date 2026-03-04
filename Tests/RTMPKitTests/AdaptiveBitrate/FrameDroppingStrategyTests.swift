// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("FrameDroppingStrategy — Drop Logic and Presets")
struct FrameDroppingStrategyTests {

    @Test("Default preset has correct values")
    func defaultPresetValues() {
        let strategy = FrameDroppingStrategy.default
        #expect(strategy.maxConsecutiveNonKeyframeDrops == 30)
        #expect(strategy.requestKeyframeAfterMaxDrops == true)
    }

    @Test("I-frame is never dropped even at maximum congestion")
    func iFrameNeverDropped() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            strategy.shouldDrop(priority: .iFrame, consecutiveDropCount: 0, congestionLevel: 1.0)
                == false
        )
    }

    @Test("B-frame dropped at congestion level above threshold")
    func bFrameDroppedAtHighCongestion() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            strategy.shouldDrop(priority: .bFrame, consecutiveDropCount: 0, congestionLevel: 0.5)
                == true
        )
    }

    @Test("B-frame not dropped below congestion threshold")
    func bFrameNotDroppedAtLowCongestion() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            strategy.shouldDrop(priority: .bFrame, consecutiveDropCount: 0, congestionLevel: 0.2)
                == false
        )
    }

    @Test("P-frame dropped at medium congestion")
    func pFrameDroppedAtMediumCongestion() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            strategy.shouldDrop(priority: .pFrame, consecutiveDropCount: 0, congestionLevel: 0.7)
                == true
        )
    }

    @Test("P-frame not dropped below congestion threshold")
    func pFrameNotDroppedBelowThreshold() {
        let strategy = FrameDroppingStrategy.default
        #expect(
            strategy.shouldDrop(priority: .pFrame, consecutiveDropCount: 0, congestionLevel: 0.5)
                == false
        )
    }

    @Test("Max consecutive drops prevents further drops for GOP recovery")
    func maxConsecutiveDropsPreventsDropping() {
        let strategy = FrameDroppingStrategy.default
        // At max consecutive drops, even P-frame at severe congestion should NOT be dropped
        #expect(
            strategy.shouldDrop(priority: .pFrame, consecutiveDropCount: 30, congestionLevel: 1.0)
                == false
        )
        // B-frame also not dropped at max consecutive count
        #expect(
            strategy.shouldDrop(priority: .bFrame, consecutiveDropCount: 30, congestionLevel: 1.0)
                == false
        )
    }

    @Test("shouldRequestKeyframe returns true at threshold for each preset")
    func shouldRequestKeyframeAtThreshold() {
        #expect(FrameDroppingStrategy.default.shouldRequestKeyframe(consecutiveDropCount: 30) == true)
        #expect(FrameDroppingStrategy.aggressive.shouldRequestKeyframe(consecutiveDropCount: 60) == true)
        #expect(FrameDroppingStrategy.conservative.shouldRequestKeyframe(consecutiveDropCount: 10) == true)

        // Below threshold returns false
        #expect(FrameDroppingStrategy.default.shouldRequestKeyframe(consecutiveDropCount: 29) == false)
        #expect(FrameDroppingStrategy.conservative.shouldRequestKeyframe(consecutiveDropCount: 9) == false)
    }

    @Test("FramePriority Comparable ordering is correct")
    func framePriorityComparable() {
        #expect(FrameDroppingStrategy.FramePriority.bFrame < .pFrame)
        #expect(FrameDroppingStrategy.FramePriority.pFrame < .iFrame)
        #expect(!(FrameDroppingStrategy.FramePriority.iFrame < .bFrame))
    }

    @Test("Custom init stores provided values")
    func customInit() {
        let strategy = FrameDroppingStrategy(
            maxConsecutiveNonKeyframeDrops: 42,
            requestKeyframeAfterMaxDrops: false
        )
        #expect(strategy.maxConsecutiveNonKeyframeDrops == 42)
        #expect(strategy.requestKeyframeAfterMaxDrops == false)
        #expect(strategy.shouldRequestKeyframe(consecutiveDropCount: 100) == false)
    }
}
