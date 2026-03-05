// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// AMF object encoding version for RTMP command messages.
///
/// Determines whether RTMP commands use AMF0 (type 20) or AMF3 (type 17)
/// encoding. Most servers use AMF0; AMF3 is required by some Wowza
/// configurations and Adobe Media Server setups.
public enum ObjectEncoding: UInt8, Sendable, Equatable {
    /// AMF0 encoding (RTMP message type 20). Default.
    case amf0 = 0x00
    /// AMF3 encoding (RTMP message type 17).
    case amf3 = 0x03
}
