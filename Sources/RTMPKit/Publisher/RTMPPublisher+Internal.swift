// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Dispatch

/// Internal error used to signal an Adobe auth retry is needed.
struct AdobeAuthRetryError: Error {
    let authQuery: String
}

// MARK: - Adobe Auth Retry

extension RTMPPublisher {

    internal func retryWithAdobeAuth(
        _ authQuery: String, originalURL: String
    ) async throws {
        guard let config = currentConfiguration else {
            throw RTMPError.authenticationFailed("No configuration")
        }
        connection.reset()
        disassembler.reset()
        session.reset()

        let separator = originalURL.contains("?") ? "&" : "?"
        let authURL = "\(originalURL)\(separator)\(authQuery)"

        do {
            let parsed = try StreamKey(url: authURL, streamKey: config.streamKey)
            let tcUrl = buildTcUrl(baseUrl: authURL, app: parsed.app)
            transitionState(to: .connecting)
            try await transport.connect(
                host: parsed.host, port: parsed.port, useTLS: parsed.useTLS
            )
            monitor.markConnectionStart(at: monotonicNow())
            transitionState(to: .handshaking)
            try await performRTMPConnect(
                streamKey: parsed, enhancedRTMP: config.enhancedRTMP,
                flashVersion: config.flashVersion,
                tcUrlOverride: tcUrl
            )
            try await sendSetChunkSize(config.chunkSize)
            transitionState(to: .connected)
            try await performCreateStream(streamName: parsed.key)
            try await performPublish(streamName: parsed.key)
            activeStreamName = parsed.key
            transitionState(to: .publishing)
            await startABRMonitorIfNeeded()
            startQualityMonitorIfNeeded()
            setupMetadataUpdater()

            let initialMeta = config.initialMetadata ?? config.metadata
            if let initialMeta {
                try await metadataUpdater?.updateStreamInfo(initialMeta)
            }
            startMessageLoop()
        } catch {
            emitEvent(.authenticationFailed(reason: "\(error)"))
            transitionState(to: .failed(.authenticationFailed("\(error)")))
            try? await transport.close()
            throw RTMPError.authenticationFailed("\(error)")
        }
    }
}

// MARK: - Setup Sequence

extension RTMPPublisher {

    internal func performRTMPConnect(
        streamKey: StreamKey,
        enhancedRTMP: Bool,
        flashVersion: String = "FMLE/3.0 (compatible; FMSc/1.0)",
        tcUrlOverride: String? = nil
    ) async throws {
        let txnID = connection.allocateTransactionID()
        var properties = ConnectProperties(
            app: streamKey.app,
            flashVer: flashVersion,
            tcUrl: tcUrlOverride ?? streamKey.tcUrl
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
        let (props, info) = try await awaitConnectResult(
            transactionID: txnID
        )
        serverInfo = parseServerInfo(properties: props, info: info)
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

    internal func awaitConnectResult(
        transactionID: Int
    ) async throws -> (properties: AMF0Value?, info: AMF0Value?) {
        while true {
            let message = try await transport.receive()
            trackBytesReceived(message)
            if message.typeID == RTMPMessage.typeIDCommandAMF0 {
                let cmd = try RTMPCommand.decode(from: message.payload)
                switch cmd {
                case .result(let txnID, let props, let info)
                where Int(txnID) == transactionID:
                    _ = connection.processResponse(
                        transactionID: transactionID
                    )
                    return (props, info)
                case .error(let txnID, _, let info)
                where Int(txnID) == transactionID:
                    _ = connection.processResponse(
                        transactionID: transactionID
                    )
                    let status = extractStatusInfo(info)

                    // Adobe challenge/response: attempt auth retry
                    if case .adobeChallenge(let user, let pass) = currentConfiguration?.authentication,
                        !hasAttemptedAdobeAuth,
                        let params = AdobeChallengeAuth.parseChallenge(from: status.description)
                    {
                        hasAttemptedAdobeAuth = true
                        emitEvent(.authenticationRequired)
                        let clientChallenge = AdobeChallengeAuth.generateClientChallenge()
                        let authQuery = AdobeChallengeAuth.computeResponse(
                            username: user, password: pass,
                            challenge: params, clientChallenge: clientChallenge
                        )
                        throw AdobeAuthRetryError(authQuery: authQuery)
                    }

                    if Self.isTokenExpiredDescription(status.description) {
                        emitEvent(.authenticationFailed(reason: "Token expired"))
                        throw RTMPError.tokenExpired
                    }

                    throw RTMPError.connectRejected(
                        code: status.code,
                        description: status.description
                    )
                default:
                    break
                }
            }
            processProtocolMessage(message)
        }
    }

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
            let status = extractStatusInfo(info)
            throw RTMPError.unexpectedResponse(
                "\(commandName) failed: \(status.code) "
                    + "\(status.description)"
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
                let status = extractStatusInfo(info)
                emitEvent(
                    .serverMessage(
                        code: status.code,
                        description: status.description
                    )
                )
                if status.code == "NetStream.Publish.Start" {
                    return
                }

                // Check known status codes first, then fall back
                // to the level field for unknown codes.
                let isKnownError =
                    RTMPStatusCode(rawValue: status.code)?
                    .isError == true
                if isKnownError || status.level == "error" {
                    throw RTMPError.publishFailed(
                        code: status.code,
                        description: status.description
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
            monitor.recordAcknowledgement(at: monotonicNow())
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
            let status = extractStatusInfo(info)
            emitEvent(
                .serverMessage(
                    code: status.code,
                    description: status.description
                )
            )
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
        monitor.recordBytesReceived(UInt64(message.payload.count))
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
    ) -> StatusInfo {
        guard case .object(let pairs) = value else {
            return StatusInfo()
        }
        var info = StatusInfo()
        for (key, val) in pairs {
            if key == "code", case .string(let s) = val {
                info.code = s
            }
            if key == "level", case .string(let s) = val {
                info.level = s
            }
            if key == "description", case .string(let s) = val {
                info.description = s
            }
        }
        return info
    }

    internal func parseServerInfo(
        properties: AMF0Value?, info: AMF0Value?
    ) -> ServerInfo {
        var result = ServerInfo()
        parseProperties(properties, into: &result)
        parseInfoObject(info, into: &result)
        return result
    }

    private func parseProperties(
        _ value: AMF0Value?, into result: inout ServerInfo
    ) {
        guard case .object(let pairs) = value else { return }
        for (key, val) in pairs {
            if key == "fmsVer", case .string(let s) = val {
                result.version = s
            }
            if key == "capabilities", case .number(let n) = val {
                result.capabilities = n
            }
        }
    }

    private func parseInfoObject(
        _ value: AMF0Value?, into result: inout ServerInfo
    ) {
        guard case .object(let pairs) = value else { return }
        for (key, val) in pairs {
            if key == "objectEncoding", case .number(let n) = val {
                result.objectEncoding = n
            }
            if key == "fourCcList" {
                let codecs = EnhancedRTMP.parseFourCcList(
                    from: val
                )
                if !codecs.isEmpty {
                    result.enhancedRTMP = true
                    result.negotiatedCodecs = codecs
                }
            }
        }
    }

    /// Build tcUrl from original URL preserving query string.
    ///
    /// The tcUrl must include the scheme, host, port, app, and any
    /// query parameters (e.g. auth credentials). The stream key
    /// portion is NOT included in the tcUrl.
    internal func buildTcUrl(baseUrl: String, app: String) -> String? {
        // Find the app segment in the URL and take everything up to
        // and including it, preserving query strings.
        // For URLs like rtmp://host:port/app?user=x&pass=y/streamkey
        // we want rtmp://host:port/app?user=x&pass=y
        guard let schemeEnd = baseUrl.range(of: "://") else { return nil }
        let afterScheme = baseUrl[schemeEnd.upperBound...]

        // Find the first slash after host:port
        guard let firstSlash = afterScheme.firstIndex(of: "/") else {
            return nil
        }

        // The path starts after the first slash
        let pathAndQuery = String(afterScheme[afterScheme.index(after: firstSlash)...])

        // Strip the stream key (last path component after app)
        // by keeping only up to and including the app segment
        let hostPart = String(baseUrl[baseUrl.startIndex...firstSlash])

        // Find query string if present
        if let queryIdx = pathAndQuery.firstIndex(of: "?") {
            let query = String(pathAndQuery[queryIdx...])
            return "\(hostPart)\(app)\(query)"
        }
        return nil
    }

    internal func buildConnectionURL(_ configuration: RTMPConfiguration) -> String {
        switch configuration.authentication {
        case .none:
            return configuration.url
        case .simple(let username, let password):
            return SimpleAuth.buildURL(
                base: configuration.url, username: username, password: password
            )
        case .token(let token, _):
            return TokenAuth.buildURL(base: configuration.url, token: token)
        case .adobeChallenge:
            return configuration.url
        }
    }

    /// Check if a rejection description indicates token expiry.
    internal static func isTokenExpiredDescription(_ desc: String) -> Bool {
        let lower = desc.lowercased()
        return lower.contains("token has expired")
            || lower.contains("token expired")
            || lower.contains("tokenexpired")
            || lower.contains("401")
    }

    internal func monotonicNow() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
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
        return .connectionFailed("\(error)")
    }
}
