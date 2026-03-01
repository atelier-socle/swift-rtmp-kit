// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import RTMPKit

@Suite("RTMPStatusCode — Cases")
struct RTMPStatusCodeCaseTests {

    @Test("all cases have non-empty rawValue")
    func nonEmptyRawValues() {
        for code in RTMPStatusCode.allCases {
            #expect(!code.rawValue.isEmpty)
        }
    }

    @Test("rawValue roundtrip for all cases")
    func rawValueRoundtrip() {
        for code in RTMPStatusCode.allCases {
            let roundtripped = RTMPStatusCode(rawValue: code.rawValue)
            #expect(roundtripped == code)
        }
    }

    @Test("CaseIterable has 11 cases")
    func caseCount() {
        #expect(RTMPStatusCode.allCases.count == 11)
    }

    @Test("unknown rawValue returns nil")
    func unknownRawValue() {
        #expect(RTMPStatusCode(rawValue: "garbage") == nil)
    }
}

@Suite("RTMPStatusCode — isSuccess")
struct RTMPStatusCodeSuccessTests {

    @Test("publishStart is success")
    func publishStartSuccess() {
        #expect(RTMPStatusCode.publishStart.isSuccess == true)
    }

    @Test("connectSuccess is success")
    func connectSuccessIsSuccess() {
        #expect(RTMPStatusCode.connectSuccess.isSuccess == true)
    }

    @Test("unpublishSuccess is success")
    func unpublishSuccessIsSuccess() {
        #expect(RTMPStatusCode.unpublishSuccess.isSuccess == true)
    }

    @Test("publishBadName is not success")
    func publishBadNameNotSuccess() {
        #expect(RTMPStatusCode.publishBadName.isSuccess == false)
    }

    @Test("connectRejected is not success")
    func connectRejectedNotSuccess() {
        #expect(RTMPStatusCode.connectRejected.isSuccess == false)
    }
}

@Suite("RTMPStatusCode — isError")
struct RTMPStatusCodeErrorTests {

    @Test("publishBadName is error")
    func publishBadNameError() {
        #expect(RTMPStatusCode.publishBadName.isError == true)
    }

    @Test("connectRejected is error")
    func connectRejectedError() {
        #expect(RTMPStatusCode.connectRejected.isError == true)
    }

    @Test("connectFailed is error")
    func connectFailedError() {
        #expect(RTMPStatusCode.connectFailed.isError == true)
    }

    @Test("streamFailed is error")
    func streamFailedError() {
        #expect(RTMPStatusCode.streamFailed.isError == true)
    }

    @Test("publishStart is not error")
    func publishStartNotError() {
        #expect(RTMPStatusCode.publishStart.isError == false)
    }

    @Test("connectSuccess is not error")
    func connectSuccessNotError() {
        #expect(RTMPStatusCode.connectSuccess.isError == false)
    }
}

@Suite("RTMPStatusCode — Category")
struct RTMPStatusCodeCategoryTests {

    @Test("connectSuccess category is connection")
    func connectCategory() {
        #expect(
            RTMPStatusCode.connectSuccess.category == .connection
        )
    }

    @Test("publishStart category is publish")
    func publishCategory() {
        #expect(RTMPStatusCode.publishStart.category == .publish)
    }

    @Test("streamReset category is stream")
    func streamCategory() {
        #expect(RTMPStatusCode.streamReset.category == .stream)
    }
}
