// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Recording Public API

extension RTMPPublisher {

    /// Start recording the stream to local files.
    ///
    /// Can be called before or after connect. If called before connect,
    /// recording starts immediately and captures frames as they are sent.
    ///
    /// - Parameter configuration: Recording configuration. Default: `.default`.
    /// - Throws: If a file cannot be created at the configured path.
    public func startRecording(
        configuration: RecordingConfiguration = .default
    ) async throws {
        let recorder = StreamRecorder(configuration: configuration)
        self.recorder = recorder
        try await recorder.start()

        recorderEventTask = Task { [weak self] in
            let stream = await recorder.events
            for await event in stream {
                guard !Task.isCancelled else { return }
                await self?.emitEvent(.recordingEvent(event))
            }
        }
    }

    /// Stop recording. Returns the final ``RecordingSegment``.
    ///
    /// - Returns: The final segment, or nil if nothing was recorded.
    /// - Throws: If closing files fails.
    @discardableResult
    public func stopRecording() async throws -> RecordingSegment? {
        recorderEventTask?.cancel()
        recorderEventTask = nil
        let segment = try await recorder?.stop()
        recorder = nil
        return segment
    }

    /// Whether recording is currently active.
    public var isRecording: Bool {
        get async {
            guard let rec = recorder else { return false }
            let recState = await rec.state
            return recState == .recording || recState == .paused
        }
    }

    /// Stream of recording events.
    public var recordingEvents: AsyncStream<RecordingEvent> {
        get async {
            guard let rec = recorder else {
                let (stream, continuation) = AsyncStream.makeStream(
                    of: RecordingEvent.self
                )
                continuation.finish()
                return stream
            }
            return await rec.events
        }
    }

    /// Forward a video frame to the recorder.
    internal func recordVideoFrame(
        _ data: [UInt8], timestamp: UInt32, isKeyframe: Bool
    ) async {
        try? await recorder?.writeVideo(
            data, timestamp: timestamp, isKeyframe: isKeyframe
        )
    }

    /// Forward an audio frame to the recorder.
    internal func recordAudioFrame(
        _ data: [UInt8], timestamp: UInt32
    ) async {
        try? await recorder?.writeAudio(data, timestamp: timestamp)
    }
}
