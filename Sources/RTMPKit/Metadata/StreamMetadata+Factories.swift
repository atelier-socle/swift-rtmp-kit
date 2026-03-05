// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Factory Methods

extension StreamMetadata {

    /// Standard H.264/AAC live stream metadata.
    ///
    /// - Parameters:
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    ///   - frameRate: Frames per second.
    ///   - videoBitrate: Video bitrate in bps.
    ///   - audioBitrate: Audio bitrate in bps.
    ///   - audioSampleRate: Audio sample rate in Hz (default: 44100).
    ///   - channels: Number of audio channels (default: 2).
    /// - Returns: Configured metadata for an H.264/AAC stream.
    public static func h264AAC(
        width: Int, height: Int, frameRate: Double,
        videoBitrate: Int, audioBitrate: Int,
        audioSampleRate: Double = 44100, channels: Int = 2
    ) -> StreamMetadata {
        var meta = StreamMetadata()
        meta.width = Double(width)
        meta.height = Double(height)
        meta.frameRate = frameRate
        meta.videoCodecID = 7.0
        meta.videoBitrate = videoBitrate
        meta.audioCodecID = 10.0
        meta.audioBitrate = audioBitrate
        meta.audioSampleRate = audioSampleRate
        meta.audioChannels = channels
        meta.isStereo = channels == 2
        return meta
    }

    /// Standard HEVC/AAC live stream metadata (Enhanced RTMP).
    ///
    /// - Parameters:
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    ///   - frameRate: Frames per second.
    ///   - videoBitrate: Video bitrate in bps.
    ///   - audioBitrate: Audio bitrate in bps.
    ///   - audioSampleRate: Audio sample rate in Hz (default: 48000).
    ///   - channels: Number of audio channels (default: 2).
    /// - Returns: Configured metadata for an HEVC/AAC stream.
    public static func hevcAAC(
        width: Int, height: Int, frameRate: Double,
        videoBitrate: Int, audioBitrate: Int,
        audioSampleRate: Double = 48000, channels: Int = 2
    ) -> StreamMetadata {
        var meta = StreamMetadata()
        meta.width = Double(width)
        meta.height = Double(height)
        meta.frameRate = frameRate
        meta.videoCodecID = 12.0
        meta.videoBitrate = videoBitrate
        meta.audioCodecID = 10.0
        meta.audioBitrate = audioBitrate
        meta.audioSampleRate = audioSampleRate
        meta.audioChannels = channels
        meta.isStereo = channels == 2
        return meta
    }

    /// Audio-only stream metadata.
    ///
    /// - Parameters:
    ///   - codecID: Audio codec identifier (e.g. 10.0 for AAC).
    ///   - bitrate: Audio bitrate in bps.
    ///   - sampleRate: Sample rate in Hz (default: 44100).
    ///   - channels: Number of audio channels (default: 2).
    /// - Returns: Configured metadata for an audio-only stream.
    public static func audioOnly(
        codecID: Double, bitrate: Int,
        sampleRate: Double = 44100, channels: Int = 2
    ) -> StreamMetadata {
        var meta = StreamMetadata()
        meta.audioCodecID = codecID
        meta.audioBitrate = bitrate
        meta.audioSampleRate = sampleRate
        meta.audioChannels = channels
        meta.isStereo = channels == 2
        return meta
    }
}
