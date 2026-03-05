// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

@testable import RTMPKit

/// Mock transport for unit testing without real network connections.
///
/// Allows tests to script server responses and verify client sends.
/// Uses actor isolation for thread safety — all access requires `await`.
public actor MockTransport: RTMPTransportProtocol {

    /// Bytes sent by the client (for verification).
    public private(set) var sentBytes: [[UInt8]] = []

    /// Scripted messages to return from receive().
    public var scriptedMessages: [RTMPMessage] = []

    /// Whether connect() was called.
    public private(set) var didConnect = false

    /// Whether close() was called.
    public private(set) var didClose = false

    /// The host passed to connect().
    public private(set) var connectHost: String?

    /// The port passed to connect().
    public private(set) var connectPort: Int?

    /// Whether TLS was requested.
    public private(set) var connectUseTLS: Bool?

    /// Error to throw on next send/receive (for error testing).
    public var nextError: Error?

    /// Internal index for scripted messages.
    private var messageIndex = 0

    /// Whether the transport is currently connected.
    public var isConnected: Bool {
        didConnect && !didClose
    }

    /// Creates a mock transport.
    public init() {}

    /// Whether to suspend indefinitely (instead of throwing) after
    /// all scripted messages have been consumed.
    public var suspendAfterMessages = false

    /// Creates a mock transport pre-loaded with scripted messages.
    ///
    /// - Parameters:
    ///   - messages: Messages to return from receive().
    ///   - suspendAfterMessages: If true, suspends instead of throwing
    ///     after all messages are consumed.
    ///   - connected: If true, starts in connected state (for server-side use).
    public init(
        messages: [RTMPMessage],
        suspendAfterMessages: Bool = false,
        connected: Bool = false
    ) {
        self.scriptedMessages = messages
        self.suspendAfterMessages = suspendAfterMessages
        self.didConnect = connected
    }

    /// Simulates connecting to a server.
    public func connect(host: String, port: Int, useTLS: Bool) async throws {
        if let error = nextError {
            nextError = nil
            throw error
        }
        connectHost = host
        connectPort = port
        connectUseTLS = useTLS
        didConnect = true
    }

    /// Records sent bytes for verification.
    public func send(_ bytes: [UInt8]) async throws {
        if let error = nextError {
            nextError = nil
            throw error
        }
        guard isConnected else {
            throw TransportError.notConnected
        }
        sentBytes.append(bytes)
    }

    /// Returns the next scripted message.
    public func receive() async throws -> RTMPMessage {
        if let error = nextError {
            nextError = nil
            throw error
        }
        guard isConnected else {
            throw TransportError.notConnected
        }
        guard messageIndex < scriptedMessages.count else {
            if suspendAfterMessages {
                // Suspend indefinitely until task is cancelled
                try await Task.sleep(for: .seconds(3600))
                throw TransportError.connectionClosed
            }
            throw TransportError.connectionClosed
        }
        let message = scriptedMessages[messageIndex]
        messageIndex += 1
        return message
    }

    /// Simulates closing the connection.
    public func close() async throws {
        didClose = true
    }

    /// Sets the scripted messages for receive().
    public func setScriptedMessages(_ messages: [RTMPMessage]) {
        scriptedMessages = messages
        messageIndex = 0
    }

    /// Sets the error to throw on the next operation.
    public func setNextError(_ error: Error?) {
        nextError = error
    }

    /// Resets the mock state for reuse.
    public func reset() {
        sentBytes.removeAll()
        scriptedMessages.removeAll()
        didConnect = false
        didClose = false
        connectHost = nil
        connectPort = nil
        connectUseTLS = nil
        nextError = nil
        messageIndex = 0
    }
}
