// Copyright 2022 Google LLC
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

import FirebaseCore
@testable import FirebaseFunctions

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseMessagingInterop
import SharedTestUtilities

import XCTest

class ContextProviderTests: XCTestCase {
  let appCheckFake = FIRAppCheckFake()
  let appCheckTokenError = FIRAppCheckTokenResultFake(token: "dummy token",
                                                      error: NSError(
                                                        domain: "testAppCheckError",
                                                        code: -1,
                                                        userInfo: nil
                                                      ))
  let appCheckTokenSuccess = FIRAppCheckTokenResultFake(token: "valid_token", error: nil)
  let messagingFake = FIRMessagingInteropFake()

  func testContextWithAuth() {
    let auth = FIRAuthInteropFake(token: "token", userID: "userID", error: nil)
    let provider = FunctionsContextProvider(auth: auth, messaging: messagingFake, appCheck: nil)
    let expectation = expectation(description: "Context should have auth keys.")
    provider.getContext { context, error in
      XCTAssertNotNil(context)
      XCTAssertEqual(context.authToken, "token")
      XCTAssertEqual(context.fcmToken, self.messagingFake.fcmToken)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)
  }

  func testContextWithAuthError() {
    let authError = NSError(domain: "com.functions.tests", code: 4, userInfo: nil)
    let auth = FIRAuthInteropFake(token: nil, userID: "userID", error: authError)
    let provider = FunctionsContextProvider(auth: auth, messaging: messagingFake, appCheck: nil)
    let expectation = expectation(description: "Completion handler should fail with Auth error.")
    provider.getContext { context, error in
      XCTAssertNotNil(context)
      XCTAssertNil(context.authToken)
      XCTAssertEqual(error as NSError?, authError)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)
  }

  func testContextWithoutAuth() {
    let provider = FunctionsContextProvider(auth: nil, messaging: nil, appCheck: nil)
    let expectation = expectation(description: "Completion handler should succeed without Auth.")
    provider.getContext { context, error in
      XCTAssertNotNil(context)
      XCTAssertNil(error)
      XCTAssertNil(context.authToken)
      XCTAssertNil(context.fcmToken)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)
  }

  func testContextWithAppCheckOnlySuccess() {
    appCheckFake.tokenResult = appCheckTokenSuccess
    let provider = FunctionsContextProvider(auth: nil, messaging: nil, appCheck: appCheckFake)
    let expectation = expectation(description: "Verify app check.")
    provider.getContext { context, error in
      XCTAssertNotNil(context)
      XCTAssertNil(error)
      XCTAssertNil(context.authToken)
      XCTAssertNil(context.fcmToken)
      XCTAssertEqual(context.appCheckToken, self.appCheckTokenSuccess.token)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)
  }

  func testContextWithAppCheckOnlyError() {
    appCheckFake.tokenResult = appCheckTokenError
    let provider = FunctionsContextProvider(auth: nil, messaging: nil, appCheck: appCheckFake)
    let expectation = expectation(description: "Verify bad app check token")
    provider.getContext { context, error in
      XCTAssertNotNil(context)
      XCTAssertNil(error)
      XCTAssertNil(context.authToken)
      XCTAssertNil(context.fcmToken)
      // Don't expect any token in the case of App Check error.
      XCTAssertNil(context.appCheckToken)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)
  }

  func testAllContextsAvailableSuccess() {
    appCheckFake.tokenResult = appCheckTokenSuccess
    let auth = FIRAuthInteropFake(token: "token", userID: "userID", error: nil)
    let provider = FunctionsContextProvider(
      auth: auth,
      messaging: messagingFake,
      appCheck: appCheckFake
    )
    let expectation = expectation(description: "All contexts available")
    provider.getContext { context, error in
      XCTAssertNotNil(context)
      XCTAssertNil(error)
      XCTAssertEqual(context.authToken, "token")
      XCTAssertEqual(context.fcmToken, self.messagingFake.fcmToken)
      XCTAssertEqual(context.appCheckToken, self.appCheckTokenSuccess.token)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)
  }

  func testAllContextsAuthAndAppCheckError() {
    appCheckFake.tokenResult = appCheckTokenError
    let authError = NSError(domain: "com.functions.tests", code: 4, userInfo: nil)
    let auth = FIRAuthInteropFake(token: nil, userID: "userID", error: authError)
    let provider = FunctionsContextProvider(
      auth: auth,
      messaging: messagingFake,
      appCheck: appCheckFake
    )
    let expectation = expectation(description: "All contexts with errors")
    provider.getContext { context, error in
      XCTAssertNotNil(context)
      XCTAssertEqual(error as NSError?, authError)
      XCTAssertNil(context.authToken)
      XCTAssertEqual(context.fcmToken, self.messagingFake.fcmToken)
      // Don't expect any token in the case of App Check error.
      XCTAssertNil(context.appCheckToken)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 0.1)
  }
}
