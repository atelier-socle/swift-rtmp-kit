// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPConnection — Transaction IDs")
struct RTMPConnectionTransactionTests {

    @Test("First allocation returns 1")
    func firstAllocationReturns1() {
        var conn = RTMPConnection()
        #expect(conn.allocateTransactionID() == 1)
    }

    @Test("Sequential allocations: 1, 2, 3")
    func sequentialAllocations() {
        var conn = RTMPConnection()
        #expect(conn.allocateTransactionID() == 1)
        #expect(conn.allocateTransactionID() == 2)
        #expect(conn.allocateTransactionID() == 3)
    }

    @Test("registerPendingCommand stores mapping")
    func registerStoresMapping() {
        var conn = RTMPConnection()
        conn.registerPendingCommand(transactionID: 1, commandName: "connect")
        #expect(conn.hasPendingTransaction(1))
    }

    @Test("processResponse returns command name for matching txnID")
    func processResponseReturnsCommandName() {
        var conn = RTMPConnection()
        conn.registerPendingCommand(transactionID: 1, commandName: "connect")
        let name = conn.processResponse(transactionID: 1)
        #expect(name == "connect")
    }

    @Test("processResponse returns nil for unknown txnID")
    func processResponseUnknown() {
        var conn = RTMPConnection()
        let name = conn.processResponse(transactionID: 99)
        #expect(name == nil)
    }

    @Test("hasPendingTransaction: false after processed")
    func noPendingAfterProcessed() {
        var conn = RTMPConnection()
        conn.registerPendingCommand(transactionID: 1, commandName: "connect")
        _ = conn.processResponse(transactionID: 1)
        #expect(!conn.hasPendingTransaction(1))
    }

    @Test("Reset resets transaction counter to 1")
    func resetResetsCounter() {
        var conn = RTMPConnection()
        _ = conn.allocateTransactionID()
        _ = conn.allocateTransactionID()
        conn.reset()
        #expect(conn.allocateTransactionID() == 1)
    }
}

@Suite("RTMPConnection — Acknowledgement")
struct RTMPConnectionAcknowledgementTests {

    @Test("Initial totalBytesReceived is 0")
    func initialBytesZero() {
        let conn = RTMPConnection()
        #expect(conn.totalBytesReceived == 0)
    }

    @Test("addBytesReceived accumulates total")
    func accumulatesTotal() {
        var conn = RTMPConnection()
        conn.setWindowAckSize(10_000)
        _ = conn.addBytesReceived(500)
        _ = conn.addBytesReceived(300)
        #expect(conn.totalBytesReceived == 800)
    }

    @Test("addBytesReceived returns nil when under window")
    func returnsNilUnderWindow() {
        var conn = RTMPConnection()
        conn.setWindowAckSize(10_000)
        let result = conn.addBytesReceived(5_000)
        #expect(result == nil)
    }

    @Test("addBytesReceived returns sequence number when exceeding window")
    func returnsSequenceWhenExceeding() {
        var conn = RTMPConnection()
        conn.setWindowAckSize(1_000)
        let result = conn.addBytesReceived(1_500)
        #expect(result != nil)
        #expect(result == 1_500)
    }

    @Test("setWindowAckSize updates threshold")
    func setWindowAckSizeUpdates() {
        var conn = RTMPConnection()
        conn.setWindowAckSize(5_000)
        #expect(conn.windowAckSize == 5_000)
    }

    @Test("After ack, lastAcknowledgedBytes updated")
    func afterAckCounterUpdated() {
        var conn = RTMPConnection()
        conn.setWindowAckSize(1_000)
        _ = conn.addBytesReceived(1_500)
        #expect(conn.lastAcknowledgedBytes == 1_500)
    }

    @Test("No ack without windowAckSize set")
    func noAckWithoutWindowSize() {
        var conn = RTMPConnection()
        let result = conn.addBytesReceived(1_000_000)
        #expect(result == nil)
    }

    @Test("Second ack after more bytes")
    func secondAckAfterMoreBytes() {
        var conn = RTMPConnection()
        conn.setWindowAckSize(1_000)
        _ = conn.addBytesReceived(1_500)
        // Now lastAck = 1500. Need 1000 more to trigger next ack.
        let result = conn.addBytesReceived(1_200)
        #expect(result != nil)
        #expect(result == 2_700)
    }
}

@Suite("RTMPConnection — Stream ID")
struct RTMPConnectionStreamIDTests {

    @Test("Initially nil")
    func initiallyNil() {
        let conn = RTMPConnection()
        #expect(conn.streamID == nil)
    }

    @Test("setStreamID stores value")
    func setStreamIDStores() {
        var conn = RTMPConnection()
        conn.setStreamID(1)
        #expect(conn.streamID == 1)
    }

    @Test("Reset clears stream ID")
    func resetClearsStreamID() {
        var conn = RTMPConnection()
        conn.setStreamID(1)
        conn.reset()
        #expect(conn.streamID == nil)
    }

    @Test("Reset clears pending commands")
    func resetClearsPending() {
        var conn = RTMPConnection()
        conn.registerPendingCommand(transactionID: 1, commandName: "connect")
        conn.reset()
        #expect(!conn.hasPendingTransaction(1))
    }
}
