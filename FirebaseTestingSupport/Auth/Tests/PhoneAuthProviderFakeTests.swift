// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import XCTest
@testable import FirebaseAuthTestingSupport

class PhoneAuthProviderFakeTests: XCTestCase {
  func testPhoneAuthProviderFakeConstructor() throws {
    let fakePhoneAuthProvider = PhoneAuthProviderFake()
    XCTAssertNotNil(fakePhoneAuthProvider)
    XCTAssertTrue(fakePhoneAuthProvider.isKind(of: PhoneAuthProvider.self))
  }

  func testVerifyPhoneNumberHandler() {
    let fakePhoneAuthProvider = PhoneAuthProviderFake()

    let handlerExpectation = expectation(description: "Handler called")
    fakePhoneAuthProvider.verifyPhoneNumberHandler = { completion in
      handlerExpectation.fulfill()

      completion(nil, nil)
    }

    let completionExpectation = expectation(description: "Completion called")
    fakePhoneAuthProvider.verifyPhoneNumber("", uiDelegate: nil) { verficationID, error in
      completionExpectation.fulfill()
      XCTAssertNil(verficationID)
      XCTAssertNil(error)
    }

    wait(for: [handlerExpectation, completionExpectation], timeout: 0.5)
  }
}
