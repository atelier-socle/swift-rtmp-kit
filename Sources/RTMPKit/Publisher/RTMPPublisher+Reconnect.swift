// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Reconnection

extension RTMPPublisher {

    internal func attemptReconnect() async {
        guard let config = currentConfiguration,
            config.reconnectPolicy.isEnabled
        else {
            return
        }

        let policy = config.reconnectPolicy
        for attempt in 0..<policy.maxAttempts {
            guard !Task.isCancelled else { return }

            transitionState(to: .reconnecting(attempt: attempt + 1))

            if let delay = policy.delay(forAttempt: attempt), delay > 0 {
                try? await Task.sleep(
                    nanoseconds: UInt64(delay * 1_000_000_000)
                )
            }

            guard !Task.isCancelled else { return }

            connection.reset()
            disassembler.reset()
            monitor.reset()
            session.reset()
            transitionState(to: .connecting)

            do {
                let parsed = try StreamKey(
                    url: config.url, streamKey: config.streamKey
                )
                try await transport.connect(
                    host: parsed.host,
                    port: parsed.port,
                    useTLS: parsed.useTLS
                )
                transitionState(to: .handshaking)
                try await performRTMPConnect(
                    streamKey: parsed,
                    enhancedRTMP: config.enhancedRTMP,
                    flashVersion: config.flashVersion
                )
                try await sendSetChunkSize(config.chunkSize)
                transitionState(to: .connected)
                try await performCreateStream(streamName: parsed.key)
                try await performPublish(streamName: parsed.key)
                transitionState(to: .publishing)
                liveVideoBitrate = 3_000_000
                await startABRMonitorIfNeeded()

                if let metadata = config.metadata {
                    try await updateMetadata(metadata)
                }
                startMessageLoop()
                return
            } catch {
                try? await transport.close()
                emitEvent(
                    .error(mapError(error))
                )
            }
        }

        transitionState(
            to: .failed(
                .reconnectExhausted(attempts: policy.maxAttempts)
            )
        )
    }
}
