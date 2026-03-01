// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validates RTMP handshake echo data.
///
/// The RTMP handshake requires that certain fields are echoed correctly
/// between client and server. This enum provides static validation methods
/// for verifying handshake integrity.
public enum HandshakeValidator: Sendable {

    /// Validate that S2 correctly echoes C1 random data.
    ///
    /// S2 bytes 8–1535 must match C1 bytes 8–1535.
    ///
    /// - Parameters:
    ///   - s2: The 1536-byte S2 packet received from the server.
    ///   - c1: The 1536-byte C1 packet sent by the client.
    /// - Returns: `true` if the random data matches.
    public static func validateS2(s2: [UInt8], c1: [UInt8]) -> Bool {
        guard s2.count == HandshakeBytes.packetSize,
            c1.count == HandshakeBytes.packetSize
        else {
            return false
        }
        return s2[8..<HandshakeBytes.packetSize]
            .elementsEqual(c1[8..<HandshakeBytes.packetSize])
    }

    /// Validate the S0 version byte.
    ///
    /// - Parameter version: The version byte from S0.
    /// - Returns: `true` if the version is the expected RTMP version (0x03).
    public static func validateVersion(_ version: UInt8) -> Bool {
        version == HandshakeBytes.version
    }

    /// Validate that a handshake packet has the correct size.
    ///
    /// - Parameter packet: The handshake packet to validate.
    /// - Returns: `true` if the packet is exactly 1536 bytes.
    public static func validatePacketSize(_ packet: [UInt8]) -> Bool {
        packet.count == HandshakeBytes.packetSize
    }
}
