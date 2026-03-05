// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RecordingConfiguration")
struct RecordingConfigurationTests {

    @Test("default format is .flv")
    func defaultFormat() {
        let config = RecordingConfiguration()
        #expect(config.format == .flv)
    }

    @Test(".default preset: no outputDirectory, no baseFilename, no segmentation")
    func defaultPreset() {
        let config = RecordingConfiguration.default
        #expect(config.outputDirectory == nil)
        #expect(config.baseFilename == nil)
        #expect(config.segmentDuration == nil)
        #expect(config.maxTotalSize == nil)
    }

    @Test("segmented sets segmentDuration")
    func segmentedPreset() {
        let config = RecordingConfiguration.segmented(
            outputDirectory: "/tmp/test",
            segmentDuration: 1800
        )
        #expect(config.segmentDuration == 1800)
        #expect(config.outputDirectory == "/tmp/test")
        #expect(config.format == .flv)
    }

    @Test("all Format cases have distinct raw values")
    func formatDistinctRawValues() {
        let rawValues = RecordingConfiguration.Format.allCases.map(\.rawValue)
        let unique = Set(rawValues)
        #expect(unique.count == rawValues.count)
    }

    @Test("Format.allCases has 4 elements")
    func formatAllCases() {
        #expect(RecordingConfiguration.Format.allCases.count == 4)
    }

    @Test("writeSidecar defaults to false")
    func writeSidecarDefault() {
        let config = RecordingConfiguration()
        #expect(!config.writeSidecar)
    }
}
