// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Writes raw elementary stream files (H.264 Annex B, AAC ADTS, etc.).
///
/// Unlike ``FLVWriter``, this produces bare codec streams without
/// a container format, suitable for tools that consume raw bitstreams.
public actor ElementaryStreamWriter {

    /// Type of elementary stream being written.
    public enum StreamType: Sendable {

        /// H.264 Annex B format (.h264 extension).
        case h264

        /// HEVC Annex B format (.hevc extension).
        case hevc

        /// AAC with ADTS framing (.aac extension).
        case aac

        /// Raw Opus frames (.opus extension).
        case opus
    }

    /// Total bytes written so far.
    public private(set) var bytesWritten: Int = 0

    /// Number of frames written.
    public private(set) var frameCount: Int = 0

    private let path: String
    private let type: StreamType
    private let fileHandle: FileHandle
    private var firstTimestamp: UInt32?
    private var lastTimestamp: UInt32 = 0
    private let startTime: Double

    /// Creates a new elementary stream writer.
    ///
    /// - Parameters:
    ///   - path: File path to create.
    ///   - type: The type of elementary stream.
    /// - Throws: If the file cannot be created.
    public init(path: String, type: StreamType) throws {
        self.path = path
        self.type = type
        self.startTime = Self.currentTime()

        let created = FileManager.default.createFile(
            atPath: path, contents: nil, attributes: nil
        )
        guard created else {
            throw FLVError.invalidFormat(
                "Cannot create file at \(path)"
            )
        }
        guard let handle = FileHandle(forWritingAtPath: path) else {
            throw FLVError.invalidFormat(
                "Cannot open file for writing at \(path)"
            )
        }
        self.fileHandle = handle
    }

    /// Write a video frame. Prepends Annex B start code.
    ///
    /// - Parameters:
    ///   - data: Raw NALU data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    /// - Throws: If writing fails.
    public func writeVideo(_ data: [UInt8], timestamp: UInt32) throws {
        trackTimestamp(timestamp)
        // Annex B start code: 0x00 0x00 0x00 0x01
        let startCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        let output = startCode + data
        fileHandle.write(Data(output))
        bytesWritten += output.count
        frameCount += 1
    }

    /// Write an audio frame. For AAC, wraps in ADTS header.
    ///
    /// - Parameters:
    ///   - data: Raw audio frame data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    /// - Throws: If writing fails.
    public func writeAudio(_ data: [UInt8], timestamp: UInt32) throws {
        trackTimestamp(timestamp)

        switch type {
        case .aac:
            let adts = buildADTSHeader(payloadSize: data.count)
            let output = adts + data
            fileHandle.write(Data(output))
            bytesWritten += output.count
        case .opus:
            fileHandle.write(Data(data))
            bytesWritten += data.count
        case .h264, .hevc:
            // Video type writer shouldn't receive audio, write raw
            fileHandle.write(Data(data))
            bytesWritten += data.count
        }
        frameCount += 1
    }

    /// Close the file and return segment metadata.
    ///
    /// - Returns: A ``RecordingSegment`` describing the completed file.
    /// - Throws: If closing fails.
    public func close() throws -> RecordingSegment {
        fileHandle.synchronizeFile()
        fileHandle.closeFile()

        let endTime = Self.currentTime()
        let duration = Double(lastTimestamp - (firstTimestamp ?? 0)) / 1000.0

        let format: RecordingConfiguration.Format =
            switch type {
            case .h264, .hevc: .videoElementaryStream
            case .aac, .opus: .audioElementaryStream
            }

        return RecordingSegment(
            filePath: path,
            format: format,
            duration: duration,
            fileSize: bytesWritten,
            videoFrameCount: (type == .h264 || type == .hevc) ? frameCount : 0,
            audioFrameCount: (type == .aac || type == .opus) ? frameCount : 0,
            startTimestamp: firstTimestamp ?? 0,
            endTimestamp: lastTimestamp,
            recordingStarted: startTime,
            recordingEnded: endTime
        )
    }

    // MARK: - Private

    private func trackTimestamp(_ timestamp: UInt32) {
        if firstTimestamp == nil {
            firstTimestamp = timestamp
        }
        lastTimestamp = timestamp
    }

    /// Build a 7-byte ADTS header for an AAC frame.
    ///
    /// - Parameter payloadSize: Size of the raw AAC frame data.
    /// - Returns: 7-byte ADTS header.
    private func buildADTSHeader(payloadSize: Int) -> [UInt8] {
        let frameLength = 7 + payloadSize

        // Byte 0: syncword high (0xFF)
        // Byte 1: syncword low (0xF) + ID=0(MPEG-4) + layer=00 + protection=1
        //        = 0xF1
        // Byte 2: profile=01(AAC-LC) + sampling_freq=3(48kHz) + private=0 + channel_high=0
        //        = (01 << 6) | (0011 << 2) | 0 | 0 = 0x4C
        // Byte 3: channel_low=10(stereo) + originality + home + copyright bits + frameLength_high
        //        channel_config=2 → high 2 bits of 3-bit field on byte 2 (bit 0) + low bit on byte 3 (bit 7,6)
        // Let's build it properly:

        var header = [UInt8](repeating: 0, count: 7)
        header[0] = 0xFF
        header[1] = 0xF1  // syncword low + MPEG-4 + no CRC

        // profile (2 bits) | sampling_freq_index (4 bits) | private (1) | channel_config high (1)
        let profile: UInt8 = 1  // AAC-LC (profile - 1 = 0 in ADTS, but ADTS uses profile_ObjectType-1)
        let samplingFreqIndex: UInt8 = 3  // 48000 Hz
        let channelConfig: UInt8 = 2  // stereo
        header[2] = (profile << 6) | (samplingFreqIndex << 2) | (channelConfig >> 2)

        // channel_config low (2 bits) | originality | home | copyright_id | copyright_start | frame_length high (2 bits)
        header[3] = ((channelConfig & 0x03) << 6) | UInt8((frameLength >> 11) & 0x03)

        // frame_length middle (8 bits)
        header[4] = UInt8((frameLength >> 3) & 0xFF)

        // frame_length low (3 bits) | buffer_fullness high (5 bits)
        header[5] = UInt8((frameLength & 0x07) << 5) | 0x1F  // buffer_fullness = 0x7FF (VBR)

        // buffer_fullness low (6 bits) | number_of_raw_data_blocks (2 bits)
        header[6] = 0xFC  // 0x7FF low 6 bits = 111111, raw blocks = 00

        return header
    }

    private static func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000.0
    }
}
