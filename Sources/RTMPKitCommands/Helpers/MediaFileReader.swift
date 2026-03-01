// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Reads FLV files and extracts audio/video tags for publishing.
///
/// Parses the FLV file header and iterates over tags, extracting
/// the audio and video data needed for RTMP publishing.
public struct MediaFileReader: Sendable {

    /// Parsed tag from an FLV file.
    public struct MediaTag: Sendable {
        /// Tag type: audio (8), video (9), or script (18).
        public let type: UInt8

        /// Tag payload data.
        public let data: [UInt8]

        /// Timestamp in milliseconds.
        public let timestamp: UInt32

        /// Whether this is an audio tag.
        public var isAudio: Bool { type == 8 }

        /// Whether this is a video tag.
        public var isVideo: Bool { type == 9 }

        /// Whether this is a script data tag.
        public var isScript: Bool { type == 18 }
    }

    /// FLV file header information.
    public struct FLVFileInfo: Sendable {
        /// Whether the file contains audio.
        public let hasAudio: Bool

        /// Whether the file contains video.
        public let hasVideo: Bool

        /// FLV format version.
        public let version: UInt8

        /// Total file size in bytes.
        public let fileSize: UInt64
    }

    /// Iterator for lazy tag reading.
    public struct MediaTagIterator: IteratorProtocol {
        private let data: [UInt8]
        private var offset: Int

        init(data: [UInt8], offset: Int) {
            self.data = data
            self.offset = offset
        }

        /// Read the next tag from the FLV data.
        public mutating func next() -> MediaTag? {
            // Skip previous tag size (4 bytes) if not at start
            guard offset + 11 <= data.count else { return nil }

            let tagType = data[offset]
            let dataSize =
                Int(data[offset + 1]) << 16
                | Int(data[offset + 2]) << 8
                | Int(data[offset + 3])

            let timestamp =
                UInt32(data[offset + 4]) << 16
                | UInt32(data[offset + 5]) << 8
                | UInt32(data[offset + 6])
                | UInt32(data[offset + 7]) << 24

            // Skip stream ID (3 bytes at offset+8..10)
            let headerSize = 11
            let payloadStart = offset + headerSize
            let payloadEnd = payloadStart + dataSize

            guard payloadEnd <= data.count else { return nil }

            let payload = Array(data[payloadStart..<payloadEnd])

            // Move past tag + 4-byte previous tag size
            offset = payloadEnd + 4

            return MediaTag(
                type: tagType, data: payload, timestamp: timestamp
            )
        }
    }

    /// The raw file data.
    private let fileData: [UInt8]

    /// The parsed FLV header info.
    public let header: FLVFileInfo

    /// Data offset after the FLV header.
    private let dataOffset: Int

    /// Open an FLV file for reading.
    ///
    /// - Parameter path: Path to the FLV file.
    /// - Throws: If the file doesn't exist or has an invalid FLV header.
    public init(path: String) throws {
        let url = URL(fileURLWithPath: path)
        let data: Data

        do {
            data = try Data(contentsOf: url)
        } catch {
            throw MediaFileReaderError.fileNotFound(path)
        }

        guard data.count >= 9 else {
            throw MediaFileReaderError.emptyFile
        }

        let bytes = Array(data)

        // Validate FLV signature: "FLV" (0x46, 0x4C, 0x56)
        guard bytes[0] == 0x46, bytes[1] == 0x4C, bytes[2] == 0x56 else {
            throw MediaFileReaderError.invalidHeader
        }

        let version = bytes[3]
        let flags = bytes[4]
        let hasAudio = (flags & 0x04) != 0
        let hasVideo = (flags & 0x01) != 0

        let headerOffset =
            Int(bytes[5]) << 24
            | Int(bytes[6]) << 16
            | Int(bytes[7]) << 8
            | Int(bytes[8])

        self.header = FLVFileInfo(
            hasAudio: hasAudio,
            hasVideo: hasVideo,
            version: version,
            fileSize: UInt64(data.count)
        )
        self.fileData = bytes
        // Skip the header + first previous tag size (4 bytes)
        self.dataOffset = headerOffset + 4
    }

    /// Read all tags from the FLV file.
    ///
    /// - Returns: Array of MediaTags in file order.
    public func readAllTags() throws -> [MediaTag] {
        var iterator = tags()
        var result: [MediaTag] = []
        while let tag = iterator.next() {
            result.append(tag)
        }
        return result
    }

    /// Read tags lazily (for large files).
    ///
    /// - Returns: An iterator that yields tags one at a time.
    public func tags() -> MediaTagIterator {
        MediaTagIterator(data: fileData, offset: dataOffset)
    }
}

/// Errors from media file reading.
public enum MediaFileReaderError: Error, Sendable, Equatable {
    /// The file was not found at the given path.
    case fileNotFound(String)

    /// The file is empty or too small.
    case emptyFile

    /// The FLV header signature is invalid.
    case invalidHeader
}
