// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("ChunkStreamID")
struct ChunkStreamIDTests {

    // MARK: - Well-Known IDs

    @Test("Protocol control CSID is 2")
    func protocolControlCSID() {
        #expect(ChunkStreamID.protocolControl.value == 2)
    }

    @Test("Command CSID is 3")
    func commandCSID() {
        #expect(ChunkStreamID.command.value == 3)
    }

    @Test("Audio CSID is 4")
    func audioCSID() {
        #expect(ChunkStreamID.audio.value == 4)
    }

    @Test("Video CSID is 6")
    func videoCSID() {
        #expect(ChunkStreamID.video.value == 6)
    }

    // MARK: - Encoded Byte Count

    @Test("CSID 2 uses 1-byte encoding")
    func encodedByteCount1Byte() {
        #expect(ChunkStreamID(value: 2).encodedByteCount == 1)
        #expect(ChunkStreamID(value: 63).encodedByteCount == 1)
    }

    @Test("CSID 64 uses 2-byte encoding")
    func encodedByteCount2Byte() {
        #expect(ChunkStreamID(value: 64).encodedByteCount == 2)
        #expect(ChunkStreamID(value: 319).encodedByteCount == 2)
    }

    @Test("CSID 320 uses 3-byte encoding")
    func encodedByteCount3Byte() {
        #expect(ChunkStreamID(value: 320).encodedByteCount == 3)
        #expect(ChunkStreamID(value: 65599).encodedByteCount == 3)
    }

    // MARK: - Validity

    @Test("CSID 0 and 1 are invalid")
    func invalidCSIDs() {
        #expect(!ChunkStreamID(value: 0).isValid)
        #expect(!ChunkStreamID(value: 1).isValid)
    }

    @Test("CSID 2 is valid")
    func validMinCSID() {
        #expect(ChunkStreamID(value: 2).isValid)
    }

    @Test("CSID 65599 is valid")
    func validMaxCSID() {
        #expect(ChunkStreamID(value: 65599).isValid)
    }

    @Test("CSID 65600 is invalid")
    func invalidOverMaxCSID() {
        #expect(!ChunkStreamID(value: 65600).isValid)
    }

    // MARK: - Encode/Decode Roundtrip

    @Test("Roundtrip CSID 2 (1-byte)")
    func roundtripCSID2() {
        assertRoundtrip(csid: 2, fmt: .full)
    }

    @Test("Roundtrip CSID 63 (max 1-byte)")
    func roundtripCSID63() {
        assertRoundtrip(csid: 63, fmt: .full)
    }

    @Test("Roundtrip CSID 64 (min 2-byte)")
    func roundtripCSID64() {
        assertRoundtrip(csid: 64, fmt: .full)
    }

    @Test("Roundtrip CSID 319 (max 2-byte)")
    func roundtripCSID319() {
        assertRoundtrip(csid: 319, fmt: .full)
    }

    @Test("Roundtrip CSID 320 (min 3-byte)")
    func roundtripCSID320() {
        assertRoundtrip(csid: 320, fmt: .full)
    }

    @Test("Roundtrip CSID 65599 (max 3-byte)")
    func roundtripCSID65599() {
        assertRoundtrip(csid: 65599, fmt: .full)
    }

    @Test("Roundtrip preserves fmt")
    func roundtripPreservesFmt() {
        assertRoundtrip(csid: 10, fmt: .sameStream)
        assertRoundtrip(csid: 10, fmt: .timestampOnly)
        assertRoundtrip(csid: 10, fmt: .continuation)
    }

    // MARK: - Encoding Details

    @Test("1-byte encoding: CSID in 6-bit field")
    func encoding1ByteDetail() {
        var buffer: [UInt8] = []
        ChunkStreamID(value: 42).encode(fmt: .full, into: &buffer)
        #expect(buffer.count == 1)
        #expect(buffer[0] & 0x3F == 42)
        #expect(buffer[0] >> 6 == 0)
    }

    @Test("2-byte encoding: byte0 has csid=0, byte1 = csid-64")
    func encoding2ByteDetail() {
        var buffer: [UInt8] = []
        ChunkStreamID(value: 200).encode(fmt: .full, into: &buffer)
        #expect(buffer.count == 2)
        #expect(buffer[0] & 0x3F == 0)
        #expect(buffer[1] == 200 - 64)
    }

    @Test("3-byte encoding: byte0 has csid=1, byte1/byte2 = adjusted LE")
    func encoding3ByteDetail() {
        var buffer: [UInt8] = []
        ChunkStreamID(value: 1000).encode(fmt: .full, into: &buffer)
        #expect(buffer.count == 3)
        #expect(buffer[0] & 0x3F == 1)
        let adjusted = 1000 - 64
        #expect(buffer[1] == UInt8(adjusted & 0xFF))
        #expect(buffer[2] == UInt8((adjusted >> 8) & 0xFF))
    }

    // MARK: - Equatable / Hashable

    @Test("CSIDs with same value are equal")
    func equatable() {
        #expect(ChunkStreamID(value: 5) == ChunkStreamID(value: 5))
    }

    @Test("CSIDs with different values are not equal")
    func notEqual() {
        #expect(ChunkStreamID(value: 5) != ChunkStreamID(value: 6))
    }

    @Test("CSIDs with same value have same hash")
    func hashable() {
        let a = ChunkStreamID(value: 42)
        let b = ChunkStreamID(value: 42)
        #expect(a.hashValue == b.hashValue)
    }

    // MARK: - Description

    @Test("Description shows CSID value")
    func descriptionFormat() {
        #expect(ChunkStreamID(value: 3).description == "CSID(3)")
    }

    // MARK: - Helpers

    private func assertRoundtrip(csid: UInt32, fmt: ChunkFormat) {
        var buffer: [UInt8] = []
        ChunkStreamID(value: csid).encode(fmt: fmt, into: &buffer)
        var offset = 0
        let result = ChunkStreamID.decode(from: buffer, offset: &offset)
        #expect(result != nil)
        #expect(result?.0 == fmt)
        #expect(result?.1.value == csid)
        #expect(offset == buffer.count)
    }
}
