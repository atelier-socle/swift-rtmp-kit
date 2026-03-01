// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Generates and parses RTMP handshake packets.
///
/// RTMP handshake packets are fixed-size binary structures exchanged
/// before any RTMP messages can flow. This enum provides factory methods
/// for generating C0/C1/C2 packets and parsing their fields.
public enum HandshakeBytes: Sendable {

    /// Handshake packet size for C1/S1/C2/S2 (1536 bytes).
    public static let packetSize = 1536

    /// RTMP protocol version.
    public static let version: UInt8 = 0x03

    /// Size of the random data within a handshake packet (bytes 8–1535).
    public static let randomDataSize = 1528

    /// Generate C0 (1 byte: RTMP version).
    public static func generateC0() -> [UInt8] {
        [version]
    }

    /// Generate C1 (1536 bytes: timestamp + zeros + random data).
    ///
    /// - Parameter timestamp: The timestamp value in big-endian (default 0).
    /// - Returns: A 1536-byte C1 packet.
    public static func generateC1(timestamp: UInt32 = 0) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: packetSize)
        // Bytes 0–3: timestamp (big-endian)
        packet[0] = UInt8((timestamp >> 24) & 0xFF)
        packet[1] = UInt8((timestamp >> 16) & 0xFF)
        packet[2] = UInt8((timestamp >> 8) & 0xFF)
        packet[3] = UInt8(timestamp & 0xFF)
        // Bytes 4–7: zeros (already zero)
        // Bytes 8–1535: random data
        for i in 8..<packetSize {
            packet[i] = UInt8.random(in: 0...255)
        }
        return packet
    }

    /// Generate C2 from S1 data (echoes S1 timestamp and random data).
    ///
    /// - Parameters:
    ///   - s1: The 1536-byte S1 packet received from the server.
    ///   - readTimestamp: The timestamp when S1 was read (default 0).
    /// - Returns: A 1536-byte C2 packet.
    public static func generateC2(
        fromS1 s1: [UInt8],
        readTimestamp: UInt32 = 0
    ) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: packetSize)
        // Bytes 0–3: echo S1 timestamp (copy first 4 bytes of S1)
        if s1.count >= 4 {
            packet[0] = s1[0]
            packet[1] = s1[1]
            packet[2] = s1[2]
            packet[3] = s1[3]
        }
        // Bytes 4–7: read timestamp (big-endian)
        packet[4] = UInt8((readTimestamp >> 24) & 0xFF)
        packet[5] = UInt8((readTimestamp >> 16) & 0xFF)
        packet[6] = UInt8((readTimestamp >> 8) & 0xFF)
        packet[7] = UInt8(readTimestamp & 0xFF)
        // Bytes 8–1535: echo S1 random data
        if s1.count >= packetSize {
            for i in 8..<packetSize {
                packet[i] = s1[i]
            }
        }
        return packet
    }

    /// Parse the timestamp from a handshake packet (first 4 bytes, big-endian).
    ///
    /// - Parameter packet: A handshake packet (at least 4 bytes).
    /// - Returns: The parsed timestamp value.
    public static func parseTimestamp(from packet: [UInt8]) -> UInt32 {
        guard packet.count >= 4 else { return 0 }
        return UInt32(packet[0]) << 24
            | UInt32(packet[1]) << 16
            | UInt32(packet[2]) << 8
            | UInt32(packet[3])
    }

    /// Extract the random data from a handshake packet (bytes 8–1535).
    ///
    /// - Parameter packet: A 1536-byte handshake packet.
    /// - Returns: The 1528-byte random data slice.
    public static func parseRandomData(from packet: [UInt8]) -> [UInt8] {
        guard packet.count >= packetSize else { return [] }
        return Array(packet[8..<packetSize])
    }
}
