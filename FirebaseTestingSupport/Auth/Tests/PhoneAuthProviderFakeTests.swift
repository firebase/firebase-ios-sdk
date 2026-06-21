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

@testable import FirebaseAuth
@testable import FirebaseAuthTestingSupport
import FirebaseCore
import Foundation
import XCTest

class PhoneAuthProviderFakeTests: XCTestCase {
  var auth: Auth!
  static var testNum = 0
  override func setUp() {
    super.setUp()
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.apiKey = "TEST_API_KEY"
    options.projectID = "myProjectID"
    PhoneAuthProviderFakeTests.testNum = PhoneAuthProviderFakeTests.testNum + 1
    let name = "test-name\(PhoneAuthProviderFakeTests.testNum)"
    FirebaseApp.configure(name: name, options: options)
    auth = Auth(
      app: FirebaseApp.app(name: name)!
    )
  }

  func testPhoneAuthProviderFakeConstructor() throws {
    let fakePhoneAuthProvider = PhoneAuthProviderFake(auth: auth)
    XCTAssertNotNil(fakePhoneAuthProvider)
  }

  func testVerifyPhoneNumberHandler() {
    let fakePhoneAuthProvider = PhoneAuthProviderFake(auth: auth)

    let handlerExpectation = expectation(description: "Handler called")
    fakePhoneAuthProvider.verifyPhoneNumberHandler = { completion in
      handlerExpectation.fulfill()
      completion("test-id", nil)
    }

    let completionExpectation = expectation(description: "Completion called")
    fakePhoneAuthProvider.verifyPhoneNumber("", uiDelegate: nil) { verificationID, error in
      completionExpectation.fulfill()
      XCTAssertEqual(verificationID, "test-id")
      XCTAssertNil(error)
    }

    wait(for: [handlerExpectation, completionExpectation], timeout: 0.5)
  }
}
