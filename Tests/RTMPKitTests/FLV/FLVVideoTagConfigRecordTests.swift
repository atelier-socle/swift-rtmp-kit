// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("FLVVideoTag Configuration Record Builders")
struct FLVVideoTagConfigRecordTests {

    // MARK: - buildAVCDecoderConfigurationRecord

    @Test("AVC config record version is 1")
    func avcConfigRecordVersion() {
        let sps: [UInt8] = [0x67, 0x64, 0x00, 0x1E, 0xAC]
        let pps: [UInt8] = [0x68, 0xEE, 0x3C, 0x80]
        let record = FLVVideoTag.buildAVCDecoderConfigurationRecord(sps: sps, pps: pps)
        #expect(record[0] == 0x01)
    }

    @Test("AVC config record extracts profile, compatibility, level from SPS")
    func avcConfigRecordProfileLevel() {
        let sps: [UInt8] = [0x67, 0x64, 0x00, 0x1E, 0xAC]
        let pps: [UInt8] = [0x68, 0xEE, 0x3C, 0x80]
        let record = FLVVideoTag.buildAVCDecoderConfigurationRecord(sps: sps, pps: pps)
        #expect(record[1] == 0x64)  // AVCProfileIndication = High
        #expect(record[2] == 0x00)  // profile_compatibility
        #expect(record[3] == 0x1E)  // AVCLevelIndication = 3.0
    }

    @Test("AVC config record lengthSizeMinusOne is 0xFF")
    func avcConfigRecordLengthSize() {
        let sps: [UInt8] = [0x67, 0x64, 0x00, 0x1E]
        let pps: [UInt8] = [0x68, 0xEE]
        let record = FLVVideoTag.buildAVCDecoderConfigurationRecord(sps: sps, pps: pps)
        // 0xFF = reserved(6 bits all 1) | lengthSizeMinusOne=3
        #expect(record[4] == 0xFF)
    }

    @Test("AVC config record numOfSPS is 0xE1")
    func avcConfigRecordNumSPS() {
        let sps: [UInt8] = [0x67, 0x64, 0x00, 0x1E]
        let pps: [UInt8] = [0x68, 0xEE]
        let record = FLVVideoTag.buildAVCDecoderConfigurationRecord(sps: sps, pps: pps)
        // 0xE1 = reserved(3 bits all 1) | numOfSPS=1
        #expect(record[5] == 0xE1)
    }

    @Test("AVC config record contains SPS length and data")
    func avcConfigRecordSPSData() {
        let sps: [UInt8] = [0x67, 0x64, 0x00, 0x1E]
        let pps: [UInt8] = [0x68, 0xEE]
        let record = FLVVideoTag.buildAVCDecoderConfigurationRecord(sps: sps, pps: pps)
        // SPS length at bytes 6-7 (UInt16 BE)
        #expect(record[6] == 0x00)
        #expect(record[7] == 0x04)  // sps.count = 4
        // SPS data at bytes 8-11
        #expect(Array(record[8..<12]) == sps)
    }

    @Test("AVC config record contains PPS count, length and data")
    func avcConfigRecordPPSData() {
        let sps: [UInt8] = [0x67, 0x64, 0x00, 0x1E]
        let pps: [UInt8] = [0x68, 0xEE]
        let record = FLVVideoTag.buildAVCDecoderConfigurationRecord(sps: sps, pps: pps)
        // numOfPPS at byte 12
        #expect(record[12] == 0x01)
        // PPS length at bytes 13-14 (UInt16 BE)
        #expect(record[13] == 0x00)
        #expect(record[14] == 0x02)  // pps.count = 2
        // PPS data at bytes 15-16
        #expect(Array(record[15..<17]) == pps)
    }

    @Test("AVC config record total length is correct")
    func avcConfigRecordTotalLength() {
        let sps: [UInt8] = [0x67, 0x64, 0x00, 0x1E]
        let pps: [UInt8] = [0x68, 0xEE]
        let record = FLVVideoTag.buildAVCDecoderConfigurationRecord(sps: sps, pps: pps)
        // 6 (header) + 2 (spsLen) + 4 (sps) + 1 (numPPS) + 2 (ppsLen) + 2 (pps) = 17
        #expect(record.count == 17)
    }

    @Test("AVC config record feeds correctly into avcSequenceHeader")
    func avcConfigRecordIntegration() {
        let sps: [UInt8] = [0x67, 0x64, 0x00, 0x1E]
        let pps: [UInt8] = [0x68, 0xEE]
        let record = FLVVideoTag.buildAVCDecoderConfigurationRecord(sps: sps, pps: pps)
        let body = FLVVideoTag.avcSequenceHeader(record)
        // 5-byte FLV header + 17-byte record = 22
        #expect(body.count == 22)
        #expect(body[0] == 0x17)
        #expect(Array(body[5...]) == record)
    }

    // MARK: - buildHEVCDecoderConfigurationRecord

    @Test("HEVC config record version is 1")
    func hevcConfigRecordVersion() {
        let vps: [UInt8] = [0x40, 0x01, 0x0C]
        let sps: [UInt8] = [
            0x42, 0x01, 0x01, 0x01, 0x60, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ]
        let pps: [UInt8] = [0x44, 0x01, 0xC0]
        let record = FLVVideoTag.buildHEVCDecoderConfigurationRecord(
            vps: vps, sps: sps, pps: pps
        )
        #expect(record[0] == 0x01)
    }

    @Test("HEVC config record has 23-byte fixed header with numOfArrays=3")
    func hevcConfigRecordFixedHeader() {
        let vps: [UInt8] = [0x40, 0x01, 0x0C]
        let sps: [UInt8] = [
            0x42, 0x01, 0x01, 0x01, 0x60, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ]
        let pps: [UInt8] = [0x44, 0x01, 0xC0]
        let record = FLVVideoTag.buildHEVCDecoderConfigurationRecord(
            vps: vps, sps: sps, pps: pps
        )
        #expect(record[22] == 0x03)
    }

    @Test("HEVC config record contains VPS, SPS, PPS NALU arrays")
    func hevcConfigRecordArrayTypes() {
        let vps: [UInt8] = [0x40]
        let sps: [UInt8] = [0x42]
        let pps: [UInt8] = [0x44]
        let record = FLVVideoTag.buildHEVCDecoderConfigurationRecord(
            vps: vps, sps: sps, pps: pps
        )
        // VPS array: NAL type = 0x20 (32)
        #expect(record[23] == 0x20)
        // SPS array: NAL type = 0x21 (33)
        let spsOffset = 23 + 1 + 2 + 2 + vps.count
        #expect(record[spsOffset] == 0x21)
        // PPS array: NAL type = 0x22 (34)
        let ppsOffset = spsOffset + 1 + 2 + 2 + sps.count
        #expect(record[ppsOffset] == 0x22)
    }

    @Test("HEVC config record total length is correct")
    func hevcConfigRecordTotalLength() {
        let vps: [UInt8] = [0x40, 0x01]
        let sps: [UInt8] = [0x42, 0x01, 0x01]
        let pps: [UInt8] = [0x44, 0x01]
        let record = FLVVideoTag.buildHEVCDecoderConfigurationRecord(
            vps: vps, sps: sps, pps: pps
        )
        // 23 (header) + 3 * (1 type + 2 numNalus + 2 naluLen) + data
        let expected = 23 + 3 * 5 + vps.count + sps.count + pps.count
        #expect(record.count == expected)
    }

    @Test("HEVC config record feeds correctly into enhancedSequenceStart")
    func hevcConfigRecordIntegration() {
        let vps: [UInt8] = [0x40]
        let sps: [UInt8] = [0x42]
        let pps: [UInt8] = [0x44]
        let record = FLVVideoTag.buildHEVCDecoderConfigurationRecord(
            vps: vps, sps: sps, pps: pps
        )
        let body = FLVVideoTag.enhancedSequenceStart(fourCC: .hevc, config: record)
        #expect(body.count == 5 + record.count)
        #expect(ExVideoHeader.isExHeader(body[0]))
        #expect(Array(body[5...]) == record)
    }
}
