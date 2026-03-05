// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Performs the RTMP handshake from the server side.
///
/// Server handshake flow:
///   1. Receive C0+C1 from client (1537 bytes)
///   2. Send S0+S1+S2 (3073 bytes):
///      S0: version byte 0x03
///      S1: timestamp(4) + zeros(4) + random(1528)
///      S2: echo of C1 (timestamp + zeros + random data from C1)
///   3. Receive C2 from client (1536 bytes) — echo of S1
///   4. Validate C2 echoes S1 correctly
struct ServerHandshake: Sendable {

    /// Errors during server-side handshake.
    enum HandshakeError: Error, Sendable, Equatable {
        /// C0 version byte is not 0x03.
        case invalidVersion(UInt8)
        /// C2 does not correctly echo S1.
        case invalidC2Echo
        /// Handshake timed out.
        case timeout
        /// Connection closed during handshake.
        case connectionClosed
    }

    /// Process C0+C1 and build the S0+S1+S2 response.
    ///
    /// - Parameter c0c1: The 1537-byte C0+C1 from the client.
    /// - Returns: A tuple of the 3073-byte S0+S1+S2 response and the S1 random
    ///   bytes needed to validate C2.
    /// - Throws: ``HandshakeError/invalidVersion(_:)`` if C0 is not 0x03.
    static func buildResponse(c0c1: [UInt8]) throws -> (s0s1s2: [UInt8], s1Random: [UInt8]) {
        let expectedC0C1Size = 1 + HandshakeBytes.packetSize
        guard c0c1.count >= expectedC0C1Size else {
            throw HandshakeError.connectionClosed
        }

        // Validate C0 version
        let version = c0c1[0]
        guard version == HandshakeBytes.version else {
            throw HandshakeError.invalidVersion(version)
        }

        // Extract C1 (bytes 1...1536)
        let c1 = Array(c0c1[1..<expectedC0C1Size])

        // Build S0: version byte
        let s0: [UInt8] = [HandshakeBytes.version]

        // Build S1: timestamp(4) + zeros(4) + random(1528)
        var s1 = [UInt8](repeating: 0, count: HandshakeBytes.packetSize)
        // Bytes 0-3: timestamp = 0
        // Bytes 4-7: zeros (already zero)
        // Bytes 8-1535: random data
        for i in 8..<HandshakeBytes.packetSize {
            s1[i] = UInt8.random(in: 0...255)
        }

        // Build S2: echo of C1
        let s2 = c1

        return (s0s1s2: s0 + s1 + s2, s1Random: s1)
    }

    /// Validate that C2 correctly echoes S1.
    ///
    /// C2 bytes 8-1535 must match S1 bytes 8-1535.
    ///
    /// - Parameters:
    ///   - c2: The 1536-byte C2 from the client.
    ///   - s1Random: The S1 bytes originally sent to the client.
    /// - Throws: ``HandshakeError/invalidC2Echo`` if the echo is incorrect.
    static func validateC2(_ c2: [UInt8], s1Random: [UInt8]) throws {
        guard c2.count == HandshakeBytes.packetSize,
            s1Random.count == HandshakeBytes.packetSize
        else {
            throw HandshakeError.invalidC2Echo
        }
        // C2 should echo S1 random data (bytes 8-1535)
        let c2Random = c2[8..<HandshakeBytes.packetSize]
        let s1RandomSlice = s1Random[8..<HandshakeBytes.packetSize]
        guard c2Random.elementsEqual(s1RandomSlice) else {
            throw HandshakeError.invalidC2Echo
        }
    }
}
