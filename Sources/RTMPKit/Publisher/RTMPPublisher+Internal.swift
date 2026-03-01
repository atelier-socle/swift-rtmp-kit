// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Setup Sequence

extension RTMPPublisher {

    internal func performRTMPConnect(
        streamKey: StreamKey,
        enhancedRTMP: Bool,
        flashVersion: String = "FMLE/3.0 (compatible; FMSc/1.0)"
    ) async throws {
        let txnID = connection.allocateTransactionID()
        var properties = ConnectProperties(
            app: streamKey.app,
            flashVer: flashVersion,
            tcUrl: streamKey.tcUrl
        )
        if enhancedRTMP {
            properties.additional.append(
                (
                    "fourCcList",
                    EnhancedRTMP.fourCcListAMF0(
                        codecs: EnhancedRTMP.defaultFourCcList
                    )
                )
            )
        }
        let cmd = RTMPCommand.connect(
            transactionID: Double(txnID), properties: properties
        )
        connection.registerPendingCommand(
            transactionID: txnID, commandName: "connect"
        )
        try await sendCommand(cmd, chunkStreamID: .command)
        try await awaitCommandResult(
            transactionID: txnID, commandName: "connect"
        )
    }

    internal func sendSetChunkSize(_ size: UInt32) async throws {
        let msg = RTMPMessage(controlMessage: .setChunkSize(size))
        try await sendRTMPMessage(msg, chunkStreamID: .protocolControl)
        disassembler.setChunkSize(size)
    }

    internal func performCreateStream(streamName: String) async throws {
        let relTxn = connection.allocateTransactionID()
        try await sendCommand(
            .releaseStream(
                transactionID: Double(relTxn), streamName: streamName
            ),
            chunkStreamID: .command
        )
        let fcTxn = connection.allocateTransactionID()
        try await sendCommand(
            .fcPublish(
                transactionID: Double(fcTxn), streamName: streamName
            ),
            chunkStreamID: .command
        )
        let createTxn = connection.allocateTransactionID()
        connection.registerPendingCommand(
            transactionID: createTxn, commandName: "createStream"
        )
        try await sendCommand(
            .createStream(transactionID: Double(createTxn)),
            chunkStreamID: .command
        )
        let result = try await awaitCommandResultValue(
            transactionID: createTxn, commandName: "createStream"
        )
        if case .number(let id) = result {
            connection.setStreamID(UInt32(id))
        } else {
            throw RTMPError.createStreamFailed("No stream ID in response")
        }
    }

    internal func performPublish(streamName: String) async throws {
        let cmd = RTMPCommand.publish(
            transactionID: 0, streamName: streamName, publishType: "live"
        )
        let msg = RTMPMessage(
            command: cmd, streamID: connection.streamID ?? 1
        )
        try await sendRTMPMessage(msg, chunkStreamID: .command)
        try await awaitPublishStatus()
    }
}

// MARK: - Message Processing

extension RTMPPublisher {

    internal func awaitCommandResult(
        transactionID: Int, commandName: String
    ) async throws {
        _ = try await awaitCommandResultValue(
            transactionID: transactionID, commandName: commandName
        )
    }

    internal func awaitCommandResultValue(
        transactionID: Int, commandName: String
    ) async throws -> AMF0Value? {
        while true {
            let message = try await transport.receive()
            trackBytesReceived(message)
            if message.typeID == RTMPMessage.typeIDCommandAMF0 {
                let cmd = try RTMPCommand.decode(from: message.payload)
                if let val = try matchResult(
                    cmd, transactionID: transactionID,
                    commandName: commandName
                ) {
                    return val
                }
            }
            processProtocolMessage(message)
        }
    }

    private func matchResult(
        _ command: RTMPCommand,
        transactionID: Int,
        commandName: String
    ) throws -> AMF0Value?? {
        switch command {
        case .result(let txnID, _, let info)
        where Int(txnID) == transactionID:
            _ = connection.processResponse(transactionID: transactionID)
            return .some(info)
        case .error(let txnID, _, let info)
        where Int(txnID) == transactionID:
            _ = connection.processResponse(transactionID: transactionID)
            let (code, desc) = extractStatusInfo(info)
            if commandName == "connect" {
                throw RTMPError.connectRejected(
                    code: code, description: desc
                )
            }
            throw RTMPError.unexpectedResponse(
                "\(commandName) failed: \(code) \(desc)"
            )
        default:
            return nil
        }
    }

    internal func awaitPublishStatus() async throws {
        while true {
            let message = try await transport.receive()
            trackBytesReceived(message)
            if message.typeID == RTMPMessage.typeIDCommandAMF0,
                let cmd = try? RTMPCommand.decode(from: message.payload),
                case .onStatus(let info) = cmd
            {
                let (code, desc) = extractStatusInfo(info)
                emitEvent(.serverMessage(code: code, description: desc))
                if code == "NetStream.Publish.Start" { return }
                if code.contains("Failed") || code.contains("Error")
                    || code.contains("Rejected")
                {
                    throw RTMPError.publishFailed(
                        code: code, description: desc
                    )
                }
            }
            processProtocolMessage(message)
        }
    }

    internal func processProtocolMessage(_ message: RTMPMessage) {
        switch message.typeID {
        case RTMPMessage.typeIDWindowAckSize:
            handleWindowAckSize(message)
        case RTMPMessage.typeIDAcknowledgement:
            handleAcknowledgement(message)
        case RTMPMessage.typeIDUserControl:
            handleUserControl(message)
        case RTMPMessage.typeIDCommandAMF0:
            handleCommand(message)
        default:
            break
        }
    }

    private func handleWindowAckSize(_ message: RTMPMessage) {
        if let ctrl = try? RTMPControlMessage.decode(
            typeID: message.typeID, payload: message.payload
        ), case .windowAcknowledgementSize(let size) = ctrl {
            connection.setWindowAckSize(size)
        }
    }

    private func handleAcknowledgement(_ message: RTMPMessage) {
        if let ctrl = try? RTMPControlMessage.decode(
            typeID: message.typeID, payload: message.payload
        ), case .acknowledgement(let seq) = ctrl {
            emitEvent(.acknowledgementReceived(sequenceNumber: seq))
        }
    }

    private func handleUserControl(_ message: RTMPMessage) {
        if let event = try? RTMPUserControlEvent.decode(
            from: message.payload
        ), case .pingRequest = event {
            emitEvent(.pingReceived)
        }
    }

    private func handleCommand(_ message: RTMPMessage) {
        if let cmd = try? RTMPCommand.decode(from: message.payload),
            case .onStatus(let info) = cmd
        {
            let (code, desc) = extractStatusInfo(info)
            emitEvent(.serverMessage(code: code, description: desc))
        }
    }

    internal func startMessageLoop() {
        let transport = self.transport
        messageTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let msg = try? await transport.receive() else {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.handleIncomingMessage(msg)
            }
        }
    }

    private func handleIncomingMessage(_ message: RTMPMessage) {
        trackBytesReceived(message)
        processProtocolMessage(message)
    }
}

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

// MARK: - Helpers

extension RTMPPublisher {

    internal func sendCommand(
        _ command: RTMPCommand, chunkStreamID: ChunkStreamID
    ) async throws {
        try await sendRTMPMessage(
            RTMPMessage(command: command), chunkStreamID: chunkStreamID
        )
    }

    internal func sendRTMPMessage(
        _ message: RTMPMessage, chunkStreamID: ChunkStreamID
    ) async throws {
        let bytes = disassembler.disassemble(
            message: message, chunkStreamID: chunkStreamID
        )
        try await transport.send(bytes)
    }

    internal func trackBytesReceived(_ message: RTMPMessage) {
        if let seqNum = connection.addBytesReceived(
            UInt64(message.payload.count)
        ) {
            let ack = RTMPControlMessage.acknowledgement(
                sequenceNumber: seqNum
            )
            let ackMsg = RTMPMessage(controlMessage: ack)
            Task {
                try? await self.sendRTMPMessage(
                    ackMsg, chunkStreamID: .protocolControl
                )
            }
        }
    }

    internal func transitionState(to newState: RTMPPublisherState) {
        session.transition(to: newState)
        emitEvent(.stateChanged(newState))
    }

    internal func emitEvent(_ event: RTMPEvent) {
        eventContinuation.yield(event)
    }

    internal func extractStatusInfo(
        _ value: AMF0Value?
    ) -> (code: String, description: String) {
        guard case .object(let pairs) = value else {
            return ("unknown", "")
        }
        var code = "unknown"
        var desc = ""
        for (key, val) in pairs {
            if key == "code", case .string(let s) = val { code = s }
            if key == "description", case .string(let s) = val { desc = s }
        }
        return (code, desc)
    }

    internal func mapError(_ error: Error) -> RTMPError {
        if let rtmpError = error as? RTMPError { return rtmpError }
        if let te = error as? TransportError {
            switch te {
            case .notConnected: return .notConnected
            case .connectionClosed: return .connectionClosed
            case .connectionTimeout: return .connectionTimeout
            case .tlsFailure(let msg): return .tlsError(msg)
            case .alreadyConnected: return .invalidState("Already connected")
            case .invalidState(let msg): return .invalidState(msg)
            }
        }
        return .connectionFailed(error.localizedDescription)
    }
}
