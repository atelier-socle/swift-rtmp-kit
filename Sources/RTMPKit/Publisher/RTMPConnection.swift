// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages RTMP command transactions and response correlation.
///
/// Tracks pending commands by transaction ID and correlates incoming
/// `_result` and `_error` responses to their original commands.
/// Also manages byte counting for acknowledgement flow control.
public struct RTMPConnection: Sendable {

    /// Next transaction ID to assign.
    public private(set) var nextTransactionID: Int

    /// The server-assigned message stream ID (from createStream response).
    public private(set) var streamID: UInt32?

    /// Window acknowledgement size set by the server.
    public private(set) var windowAckSize: UInt32?

    /// Total bytes received (for acknowledgement tracking).
    public private(set) var totalBytesReceived: UInt64

    /// Last acknowledged byte count.
    public private(set) var lastAcknowledgedBytes: UInt64

    /// Pending commands keyed by transaction ID.
    private var pendingCommands: [Int: String]

    /// Creates a new connection manager.
    public init() {
        self.nextTransactionID = 1
        self.streamID = nil
        self.windowAckSize = nil
        self.totalBytesReceived = 0
        self.lastAcknowledgedBytes = 0
        self.pendingCommands = [:]
    }

    /// Allocate the next transaction ID.
    ///
    /// - Returns: The allocated ID (starts at 1, increments sequentially).
    public mutating func allocateTransactionID() -> Int {
        let id = nextTransactionID
        nextTransactionID += 1
        return id
    }

    /// Record that a command was sent with a given transaction ID.
    ///
    /// - Parameters:
    ///   - transactionID: The transaction ID assigned to the command.
    ///   - commandName: The command name (e.g., "connect", "createStream").
    public mutating func registerPendingCommand(
        transactionID: Int,
        commandName: String
    ) {
        pendingCommands[transactionID] = commandName
    }

    /// Process an incoming `_result` or `_error` response.
    ///
    /// Correlates the response to the original command via transaction ID
    /// and removes it from the pending set.
    ///
    /// - Parameter transactionID: The transaction ID from the response.
    /// - Returns: The original command name, or `nil` if no matching
    ///   pending command was found.
    public mutating func processResponse(transactionID: Int) -> String? {
        pendingCommands.removeValue(forKey: transactionID)
    }

    /// Check if a transaction is pending.
    ///
    /// - Parameter transactionID: The transaction ID to check.
    /// - Returns: `true` if the transaction is still pending.
    public func hasPendingTransaction(_ transactionID: Int) -> Bool {
        pendingCommands[transactionID] != nil
    }

    /// Update bytes received and check if acknowledgement is needed.
    ///
    /// The RTMP spec requires the client to send an acknowledgement
    /// when `totalBytesReceived - lastAcknowledgedBytes` exceeds the
    /// server's window acknowledgement size.
    ///
    /// - Parameter count: Number of bytes received.
    /// - Returns: The sequence number to acknowledge, or `nil` if not
    ///   needed yet.
    public mutating func addBytesReceived(_ count: UInt64) -> UInt32? {
        totalBytesReceived += count
        guard let windowSize = windowAckSize else { return nil }
        let delta = totalBytesReceived - lastAcknowledgedBytes
        guard delta >= UInt64(windowSize) else { return nil }
        lastAcknowledgedBytes = totalBytesReceived
        // Sequence number wraps at UInt32.max per RTMP spec.
        return UInt32(truncatingIfNeeded: totalBytesReceived)
    }

    /// Set the window acknowledgement size.
    ///
    /// - Parameter size: The window size in bytes.
    public mutating func setWindowAckSize(_ size: UInt32) {
        windowAckSize = size
    }

    /// Set the stream ID from createStream response.
    ///
    /// - Parameter id: The server-assigned message stream ID.
    public mutating func setStreamID(_ id: UInt32) {
        streamID = id
    }

    /// Reset for reconnection.
    ///
    /// Clears all pending commands, resets transaction counter,
    /// and clears stream ID and byte counters.
    public mutating func reset() {
        nextTransactionID = 1
        streamID = nil
        windowAckSize = nil
        totalBytesReceived = 0
        lastAcknowledgedBytes = 0
        pendingCommands = [:]
    }
}
