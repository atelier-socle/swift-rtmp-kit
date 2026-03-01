// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import RTMPKitCommands

@Suite("MediaFileReader — FLV Header")
struct MediaFileReaderHeaderTests {

    @Test("parse valid FLV header with audio and video")
    func validHeaderAudioVideo() throws {
        let path = try writeTempFLV(flags: 0x05)
        let reader = try MediaFileReader(path: path)
        #expect(reader.header.hasAudio == true)
        #expect(reader.header.hasVideo == true)
        #expect(reader.header.version == 1)
    }

    @Test("parse valid FLV header with audio only")
    func audioOnly() throws {
        let path = try writeTempFLV(flags: 0x04)
        let reader = try MediaFileReader(path: path)
        #expect(reader.header.hasAudio == true)
        #expect(reader.header.hasVideo == false)
    }

    @Test("parse valid FLV header with video only")
    func videoOnly() throws {
        let path = try writeTempFLV(flags: 0x01)
        let reader = try MediaFileReader(path: path)
        #expect(reader.header.hasAudio == false)
        #expect(reader.header.hasVideo == true)
    }

    @Test("invalid header throws error")
    func invalidHeader() throws {
        let path = try writeTempFile(bytes: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        #expect(throws: MediaFileReaderError.self) {
            _ = try MediaFileReader(path: path)
        }
    }

    @Test("empty file throws error")
    func emptyFile() throws {
        let path = try writeTempFile(bytes: [])
        #expect(throws: MediaFileReaderError.self) {
            _ = try MediaFileReader(path: path)
        }
    }

    @Test("file not found throws error")
    func fileNotFound() {
        #expect(throws: MediaFileReaderError.self) {
            _ = try MediaFileReader(path: "/nonexistent/file.flv")
        }
    }

    @Test("fileSize is correct")
    func fileSizeCorrect() throws {
        let path = try writeTempFLV(flags: 0x05)
        let reader = try MediaFileReader(path: path)
        #expect(reader.header.fileSize > 0)
    }
}

@Suite("MediaFileReader — MediaTag")
struct MediaFileReaderTagTests {

    @Test("audio tag type is 8")
    func audioTagType() {
        let tag = MediaFileReader.MediaTag(
            type: 8, data: [0x01], timestamp: 0
        )
        #expect(tag.isAudio == true)
        #expect(tag.isVideo == false)
        #expect(tag.isScript == false)
    }

    @Test("video tag type is 9")
    func videoTagType() {
        let tag = MediaFileReader.MediaTag(
            type: 9, data: [0x01], timestamp: 0
        )
        #expect(tag.isAudio == false)
        #expect(tag.isVideo == true)
        #expect(tag.isScript == false)
    }

    @Test("script tag type is 18")
    func scriptTagType() {
        let tag = MediaFileReader.MediaTag(
            type: 18, data: [0x01], timestamp: 0
        )
        #expect(tag.isAudio == false)
        #expect(tag.isVideo == false)
        #expect(tag.isScript == true)
    }

    @Test("timestamp is stored correctly")
    func timestampStored() {
        let tag = MediaFileReader.MediaTag(
            type: 8, data: [], timestamp: 12345
        )
        #expect(tag.timestamp == 12345)
    }

    @Test("read tags from constructed FLV")
    func readTags() throws {
        let path = try writeFLVWithTags()
        let reader = try MediaFileReader(path: path)
        let tags = try reader.readAllTags()
        #expect(tags.count > 0)
    }
}

// MARK: - MediaFileReaderError Descriptions

@Suite("MediaFileReaderError — Description")
struct MediaFileReaderErrorDescriptionTests {

    @Test("fileNotFound includes path")
    func fileNotFoundDescription() {
        let err = MediaFileReaderError.fileNotFound("/tmp/missing.flv")
        #expect(err.description == "File not found: /tmp/missing.flv")
    }

    @Test("emptyFile has human-readable description")
    func emptyFileDescription() {
        let err = MediaFileReaderError.emptyFile
        #expect(
            err.description == "File is empty or too small to be a valid FLV"
        )
    }

    @Test("invalidHeader has human-readable description")
    func invalidHeaderDescription() {
        let err = MediaFileReaderError.invalidHeader
        #expect(
            err.description
                == "Invalid FLV file: not a valid FLV header"
        )
    }

    @Test("all cases have non-empty description")
    func allDescriptionsNonEmpty() {
        let errors: [MediaFileReaderError] = [
            .fileNotFound("/path"),
            .emptyFile,
            .invalidHeader
        ]
        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }
}

// MARK: - Helpers

private func writeTempFLV(flags: UInt8) throws -> String {
    // FLV header: "FLV" + version(1) + flags + dataOffset(9)
    let header: [UInt8] = [
        0x46, 0x4C, 0x56,  // "FLV"
        0x01,  // version 1
        flags,  // audio/video flags
        0x00, 0x00, 0x00, 0x09  // data offset = 9
    ]
    // Previous tag size 0 (first)
    let prevTagSize: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    return try writeTempFile(bytes: header + prevTagSize)
}

private func writeFLVWithTags() throws -> String {
    // FLV header
    var data: [UInt8] = [
        0x46, 0x4C, 0x56,  // "FLV"
        0x01,  // version 1
        0x05,  // audio + video
        0x00, 0x00, 0x00, 0x09  // data offset = 9
    ]
    // Previous tag size 0
    data += [0x00, 0x00, 0x00, 0x00]

    // Audio tag: type=8, dataSize=2, timestamp=0, streamID=0
    let audioPayload: [UInt8] = [0xAF, 0x00]
    data += [
        0x08,  // tag type = audio
        0x00, 0x00, 0x02,  // data size = 2
        0x00, 0x00, 0x00,  // timestamp low 24 bits
        0x00,  // timestamp extended
        0x00, 0x00, 0x00  // stream ID
    ]
    data += audioPayload
    // Previous tag size
    let audioTagSize: UInt32 = 11 + 2
    data += [
        UInt8((audioTagSize >> 24) & 0xFF),
        UInt8((audioTagSize >> 16) & 0xFF),
        UInt8((audioTagSize >> 8) & 0xFF),
        UInt8(audioTagSize & 0xFF)
    ]

    // Video tag: type=9, dataSize=3, timestamp=33, streamID=0
    let videoPayload: [UInt8] = [0x17, 0x00, 0x00]
    data += [
        0x09,  // tag type = video
        0x00, 0x00, 0x03,  // data size = 3
        0x00, 0x00, 0x21,  // timestamp = 33ms
        0x00,  // timestamp extended
        0x00, 0x00, 0x00  // stream ID
    ]
    data += videoPayload
    let videoTagSize: UInt32 = 11 + 3
    data += [
        UInt8((videoTagSize >> 24) & 0xFF),
        UInt8((videoTagSize >> 16) & 0xFF),
        UInt8((videoTagSize >> 8) & 0xFF),
        UInt8(videoTagSize & 0xFF)
    ]

    return try writeTempFile(bytes: data)
}

private func writeTempFile(bytes: [UInt8]) throws -> String {
    let dir = FileManager.default.temporaryDirectory
    let path = dir.appendingPathComponent(
        "test-\(UUID().uuidString).flv"
    ).path
    _ = FileManager.default.createFile(
        atPath: path,
        contents: Data(bytes)
    )
    return path
}
