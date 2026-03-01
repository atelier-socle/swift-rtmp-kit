// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// RTMP handshake state machine (client-side).
///
/// Manages the 3-phase handshake exchange required before RTMP messages
/// can flow. The client sends C0+C1, receives S0+S1+S2, then sends C2.
public struct RTMPHandshake: Sendable {

    /// Handshake states.
    public enum State: Sendable, Equatable {
        /// Initial state, no data exchanged.
        case idle
        /// C0+C1 have been generated and sent.
        case sentC0C1
        /// S0+S1+S2 have been received and validated.
        case receivedS0S1S2
        /// Handshake completed successfully.
        case complete
        /// Handshake failed with a reason.
        case failed(String)
    }

    /// Errors specific to the handshake state machine.
    public enum HandshakeError: Error, Sendable, Equatable {
        /// Operation attempted in an invalid state.
        case invalidState(State)
        /// S0 version mismatch.
        case versionMismatch(UInt8)
        /// Invalid packet size received.
        case invalidPacketSize(Int)
    }

    /// Current state.
    public private(set) var state: State

    /// Stored C1 for S2 validation.
    private var c1: [UInt8]?

    /// Stored S1 for C2 generation.
    private var s1: [UInt8]?

    /// Creates a new handshake in idle state.
    public init() {
        self.state = .idle
    }

    /// Generate C0+C1 bytes to send to server.
    ///
    /// Transitions: `idle` → `sentC0C1`.
    ///
    /// - Returns: 1537 bytes (1 byte C0 + 1536 bytes C1).
    /// - Throws: `HandshakeError.invalidState` if not in `idle` state.
    public mutating func generateC0C1() throws -> [UInt8] {
        guard state == .idle else {
            throw HandshakeError.invalidState(state)
        }
        let c0 = HandshakeBytes.generateC0()
        let generatedC1 = HandshakeBytes.generateC1()
        c1 = generatedC1
        state = .sentC0C1
        return c0 + generatedC1
    }

    /// Process S0+S1+S2 received from server.
    ///
    /// Validates S0 version and stores S1 for C2 generation.
    /// Transitions: `sentC0C1` → `receivedS0S1S2`.
    ///
    /// - Parameter bytes: 3073 bytes (1 byte S0 + 1536 bytes S1 + 1536 bytes S2).
    /// - Throws: `HandshakeError` on invalid state, version, or size.
    public mutating func processS0S1S2(_ bytes: [UInt8]) throws {
        guard state == .sentC0C1 else {
            throw HandshakeError.invalidState(state)
        }
        let expectedSize = 1 + HandshakeBytes.packetSize * 2
        guard bytes.count == expectedSize else {
            state = .failed("Invalid S0S1S2 size: \(bytes.count)")
            throw HandshakeError.invalidPacketSize(bytes.count)
        }
        let s0Version = bytes[0]
        guard HandshakeValidator.validateVersion(s0Version) else {
            state = .failed("Version mismatch: \(s0Version)")
            throw HandshakeError.versionMismatch(s0Version)
        }
        s1 = Array(bytes[1..<(1 + HandshakeBytes.packetSize)])
        let s2 = Array(
            bytes[(1 + HandshakeBytes.packetSize)..<bytes.count]
        )
        if let storedC1 = c1 {
            if !HandshakeValidator.validateS2(s2: s2, c1: storedC1) {
                state = .failed("S2 echo validation failed")
            }
        }
        if case .failed = state { return }
        state = .receivedS0S1S2
    }

    /// Generate C2 bytes to send to server.
    ///
    /// C2 echoes S1's timestamp and random data.
    /// Transitions: `receivedS0S1S2` → `complete`.
    ///
    /// - Returns: 1536-byte C2 packet.
    /// - Throws: `HandshakeError.invalidState` if not in `receivedS0S1S2` state.
    public mutating func generateC2() throws -> [UInt8] {
        guard state == .receivedS0S1S2 else {
            throw HandshakeError.invalidState(state)
        }
        guard let storedS1 = s1 else {
            throw HandshakeError.invalidState(state)
        }
        let c2 = HandshakeBytes.generateC2(fromS1: storedS1)
        state = .complete
        return c2
    }

    /// Reset to idle state for reconnection.
    public mutating func reset() {
        state = .idle
        c1 = nil
        s1 = nil
    }
}
