// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Message Handling

extension RTMPServer {

    func handleMessage(
        _ message: RTMPMessage, session: RTMPServerSession
    ) async throws {
        switch message.typeID {
        case RTMPMessage.typeIDCommandAMF0:
            try await handleCommand(message, session: session)
        case RTMPMessage.typeIDAudio:
            await handleAudio(message, session: session)
        case RTMPMessage.typeIDVideo:
            await handleVideo(message, session: session)
        case RTMPMessage.typeIDDataAMF0:
            await handleDataMessage(message, session: session)
        case RTMPMessage.typeIDSetChunkSize:
            await handleSetChunkSize(message, session: session)
        default:
            break
        }
    }

    private func handleCommand(
        _ message: RTMPMessage, session: RTMPServerSession
    ) async throws {
        let command = try RTMPCommand.decode(from: message.payload)

        switch command {
        case .connect(let txnID, let props):
            await session.transitionToConnected(appName: props.app)
            try await session.sendConnectResult(transactionID: txnID)
            emitEvent(.sessionConnected(session))
            await delegate?.serverSessionDidConnect(session)

        case .releaseStream(let txnID, _):
            try await session.sendResultAck(transactionID: txnID)

        case .fcPublish(let txnID, let name):
            await session.transitionToPublishing(streamName: name)
            try await session.sendOnFCPublish(streamName: name)
            _ = txnID

        case .createStream(let txnID):
            try await session.sendCreateStreamResult(
                transactionID: txnID, streamID: 1.0
            )

        case .publish(_, let name, _):
            let accepted: Bool
            if let del = delegate {
                accepted = await del.serverSession(
                    session, shouldAcceptStream: name
                )
            } else {
                accepted = true
            }

            if accepted {
                await session.transitionToPublishing(streamName: name)
                try await session.sendPublishStart(streamName: name)
                emitEvent(
                    .streamStarted(session: session, streamName: name)
                )
            } else {
                try await session.sendPublishBadName(streamName: name)
            }

        case .fcUnpublish(_, let name):
            try await session.sendOnFCUnpublish(streamName: name)
            let streamName = await session.streamName ?? name
            emitEvent(
                .streamStopped(session: session, streamName: streamName)
            )

        case .deleteStream:
            let sessionID = session.id
            await handleSessionDisconnect(
                sessionID, reason: "Publisher deleted stream"
            )

        default:
            break
        }
    }

    private func handleAudio(
        _ message: RTMPMessage, session: RTMPServerSession
    ) async {
        await session.recordAudioFrame()
        let data = message.payload
        let sessionID = session.id
        emitEvent(
            .audioFrame(
                sessionID: sessionID,
                data: data,
                timestamp: message.timestamp
            )
        )
        await delegate?.serverSession(
            session,
            didReceiveAudio: data,
            timestamp: message.timestamp
        )
    }

    private func handleVideo(
        _ message: RTMPMessage, session: RTMPServerSession
    ) async {
        await session.recordVideoFrame()
        let data = message.payload
        let isKeyframe = !data.isEmpty && (data[0] & 0xF0) == 0x10
        let sessionID = session.id
        emitEvent(
            .videoFrame(
                sessionID: sessionID,
                data: data,
                timestamp: message.timestamp,
                isKeyframe: isKeyframe
            )
        )
        await delegate?.serverSession(
            session,
            didReceiveVideo: data,
            timestamp: message.timestamp,
            isKeyframe: isKeyframe
        )
    }

    private func handleDataMessage(
        _ message: RTMPMessage, session: RTMPServerSession
    ) async {
        guard
            let dataMsg = try? RTMPDataMessage.decode(
                from: message.payload
            )
        else { return }

        switch dataMsg {
        case .setDataFrame(let metadata):
            await delegate?.serverSession(
                session, didReceiveMetadata: metadata
            )
        case .onMetaData(let amfValue):
            let metadata = StreamMetadata.fromAMF0(amfValue)
            await delegate?.serverSession(
                session, didReceiveMetadata: metadata
            )
        }
    }

    private func handleSetChunkSize(
        _ message: RTMPMessage, session: RTMPServerSession
    ) async {
        guard message.payload.count >= 4 else { return }
        let size =
            UInt32(message.payload[0]) << 24
            | UInt32(message.payload[1]) << 16
            | UInt32(message.payload[2]) << 8
            | UInt32(message.payload[3])
        await session.setReceiveChunkSize(size)
    }

    func handleSessionDisconnect(
        _ sessionID: UUID, reason: String
    ) async {
        guard let session = sessions[sessionID] else { return }
        sessionTasks[sessionID]?.cancel()
        sessionTasks.removeValue(forKey: sessionID)
        await session.close()
        sessions.removeValue(forKey: sessionID)
        emitEvent(.sessionDisconnected(id: sessionID, reason: reason))
        await delegate?.serverSessionDidDisconnect(session, reason: reason)
    }
}
