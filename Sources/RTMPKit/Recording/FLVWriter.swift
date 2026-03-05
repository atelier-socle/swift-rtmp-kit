// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Writes FLV container files from raw audio/video frames.
///
/// Implements the FLV file format (Adobe FLV spec, version 10).
///
/// ## FLV Structure
/// - 9-byte header ("FLV" + version + flags + data offset)
/// - Sequence of tags, each preceded by a 4-byte PreviousTagSize
///
/// ## FLV Tag (11-byte header + data)
/// - TagType: 1 byte (0x08=audio, 0x09=video, 0x12=script)
/// - DataSize: 3 bytes big-endian
/// - Timestamp: 3 bytes big-endian (low 24 bits)
/// - TimestampExtended: 1 byte (high 8 bits)
/// - StreamID: 3 bytes (always 0)
/// - Data: DataSize bytes
/// - PreviousTagSize: 4 bytes big-endian (= 11 + DataSize)
public actor FLVWriter {

    /// Total bytes written so far.
    public private(set) var bytesWritten: Int = 0

    /// Number of video frames written.
    public private(set) var videoFrameCount: Int = 0

    /// Number of audio frames written.
    public private(set) var audioFrameCount: Int = 0

    private let path: String
    private let fileHandle: FileHandle
    private var firstTimestamp: UInt32?
    private var lastTimestamp: UInt32 = 0
    private let startTime: Double
    private var lastTagSize: UInt32 = 0

    /// Open a new FLV file at the given path. Writes the FLV header immediately.
    ///
    /// - Parameters:
    ///   - path: File path to create.
    ///   - hasVideo: Whether video tags will be written. Default: true.
    ///   - hasAudio: Whether audio tags will be written. Default: true.
    /// - Throws: If the file cannot be created.
    public init(
        path: String,
        hasVideo: Bool = true,
        hasAudio: Bool = true
    ) throws {
        self.path = path
        self.startTime = Self.currentTime()

        let created = FileManager.default.createFile(
            atPath: path, contents: nil, attributes: nil
        )
        guard created else {
            throw FLVError.invalidFormat("Cannot create file at \(path)")
        }
        guard let handle = FileHandle(forWritingAtPath: path) else {
            throw FLVError.invalidFormat("Cannot open file for writing at \(path)")
        }
        self.fileHandle = handle

        // Write FLV header
        let header = FLVHeader(hasAudio: hasAudio, hasVideo: hasVideo)
        let headerBytes = header.encode()
        fileHandle.write(Data(headerBytes))
        bytesWritten += headerBytes.count

        // Write initial PreviousTagSize (0)
        let zeroTag = Self.encodeUInt32(0)
        fileHandle.write(Data(zeroTag))
        bytesWritten += 4
    }

    /// Write a video tag.
    ///
    /// - Parameters:
    ///   - data: Raw video data (NALU or sequence header bytes).
    ///   - timestamp: Presentation timestamp in milliseconds.
    ///   - isKeyframe: Whether this is a keyframe.
    /// - Throws: If writing fails.
    public func writeVideo(
        _ data: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) throws {
        trackTimestamp(timestamp)
        let tagData = buildVideoTagData(data, isKeyframe: isKeyframe)
        try writeTag(
            type: FLVTagType.video.rawValue,
            data: tagData,
            timestamp: timestamp
        )
        videoFrameCount += 1
    }

    /// Write an audio tag.
    ///
    /// - Parameters:
    ///   - data: Raw audio data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    /// - Throws: If writing fails.
    public func writeAudio(_ data: [UInt8], timestamp: UInt32) throws {
        trackTimestamp(timestamp)
        let tagData = buildAudioTagData(data)
        try writeTag(
            type: FLVTagType.audio.rawValue,
            data: tagData,
            timestamp: timestamp
        )
        audioFrameCount += 1
    }

    /// Write a script tag (e.g. onMetaData). Uses AMF0 encoding.
    ///
    /// - Parameters:
    ///   - name: Tag name (e.g. "onMetaData").
    ///   - metadata: Key-value pairs to encode.
    /// - Throws: If writing fails.
    public func writeScriptTag(
        name: String, metadata: [String: AMF0Value]
    ) throws {
        let pairs = metadata.map { ($0.key, $0.value) }
        let body = FLVScriptTag.encode(
            values: [.string(name), .object(pairs)]
        )
        try writeTag(
            type: FLVTagType.scriptData.rawValue,
            data: body,
            timestamp: 0
        )
    }

    /// Flush all pending writes to disk and close the file.
    ///
    /// - Returns: A ``RecordingSegment`` describing the completed file.
    /// - Throws: If closing fails.
    public func close() throws -> RecordingSegment {
        fileHandle.synchronizeFile()
        fileHandle.closeFile()

        let endTime = Self.currentTime()
        let duration = Double(lastTimestamp - (firstTimestamp ?? 0)) / 1000.0

        return RecordingSegment(
            filePath: path,
            format: .flv,
            duration: duration,
            fileSize: bytesWritten,
            videoFrameCount: videoFrameCount,
            audioFrameCount: audioFrameCount,
            startTimestamp: firstTimestamp ?? 0,
            endTimestamp: lastTimestamp,
            recordingStarted: startTime,
            recordingEnded: endTime
        )
    }

    // MARK: - Private

    private func writeTag(
        type: UInt8, data: [UInt8], timestamp: UInt32
    ) throws {
        let dataSize = data.count

        // Tag header (11 bytes)
        var header = [UInt8](repeating: 0, count: 11)
        header[0] = type

        // DataSize (3 bytes big-endian)
        header[1] = UInt8((dataSize >> 16) & 0xFF)
        header[2] = UInt8((dataSize >> 8) & 0xFF)
        header[3] = UInt8(dataSize & 0xFF)

        // Timestamp (3 bytes low + 1 byte extended)
        header[4] = UInt8((timestamp >> 16) & 0xFF)
        header[5] = UInt8((timestamp >> 8) & 0xFF)
        header[6] = UInt8(timestamp & 0xFF)
        header[7] = UInt8((timestamp >> 24) & 0xFF)  // extended

        // StreamID (3 bytes, always 0) — already zero

        fileHandle.write(Data(header))
        fileHandle.write(Data(data))

        // PreviousTagSize (11 + dataSize)
        let prevTagSize = UInt32(11 + dataSize)
        let prevTagBytes = Self.encodeUInt32(prevTagSize)
        fileHandle.write(Data(prevTagBytes))

        lastTagSize = prevTagSize
        bytesWritten += 11 + dataSize + 4
    }

    private func buildVideoTagData(
        _ data: [UInt8], isKeyframe: Bool
    ) -> [UInt8] {
        // VIDEODATA: byte 0 = (frameType << 4) | codecID
        // frameType: 1=keyframe, 2=inter; codecID: 7=H.264
        let frameType: UInt8 = isKeyframe ? 0x10 : 0x20
        let codecID: UInt8 = 0x07
        let headerByte = frameType | codecID

        // AVCPacketType: 1=NALU (assume raw frames)
        // CompositionTime: 0x000000
        return [headerByte, 0x01, 0x00, 0x00, 0x00] + data
    }

    private func buildAudioTagData(_ data: [UInt8]) -> [UInt8] {
        // AUDIODATA: byte 0 = (soundFormat << 4) | flags
        // soundFormat=10 (AAC), rate=3 (44.1kHz), size=1 (16-bit), type=1 (stereo)
        // = 0xAF
        // AACPacketType: 1=raw AAC frame
        return [0xAF, 0x01] + data
    }

    private func trackTimestamp(_ timestamp: UInt32) {
        if firstTimestamp == nil {
            firstTimestamp = timestamp
        }
        lastTimestamp = timestamp
    }

    private static func encodeUInt32(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }

    private static func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000.0
    }
}
