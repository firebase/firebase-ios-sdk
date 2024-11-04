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

  func testAsyncContextWithAuth() async throws {
    let auth = FIRAuthInteropFake(token: "token", userID: "userID", error: nil)
    let provider = FunctionsContextProvider(auth: auth, messaging: messagingFake, appCheck: nil)

    let context = try await provider.context(options: nil)

    XCTAssertNotNil(context)
    XCTAssertEqual(context.authToken, "token")
    XCTAssertEqual(context.fcmToken, messagingFake.fcmToken)
  }

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

  func testAsyncContextWithAuthError() async {
    let authError = NSError(domain: "com.functions.tests", code: 4, userInfo: nil)
    let auth = FIRAuthInteropFake(token: nil, userID: "userID", error: authError)
    let provider = FunctionsContextProvider(auth: auth, messaging: messagingFake, appCheck: nil)

    do {
      _ = try await provider.context(options: nil)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as NSError, authError)
    }
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

  func testAsyncContextWithoutAuth() async throws {
    let provider = FunctionsContextProvider(auth: nil, messaging: nil, appCheck: nil)

    let context = try await provider.context(options: nil)

    XCTAssertNil(context.authToken)
    XCTAssertNil(context.fcmToken)
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

  func testAsyncContextWithAppCheckOnlySuccess() async throws {
    appCheckFake.tokenResult = appCheckTokenSuccess
    let provider = FunctionsContextProvider(auth: nil, messaging: nil, appCheck: appCheckFake)

    let context = try await provider.context(options: nil)

    XCTAssertNil(context.authToken)
    XCTAssertNil(context.fcmToken)
    XCTAssertEqual(context.appCheckToken, appCheckTokenSuccess.token)
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

  func testAsyncContextWithAppCheckOnlyError() async throws {
    appCheckFake.tokenResult = appCheckTokenError
    let provider = FunctionsContextProvider(auth: nil, messaging: nil, appCheck: appCheckFake)

    let context = try await provider.context(options: nil)

    XCTAssertNil(context.authToken)
    XCTAssertNil(context.fcmToken)
    // Don't expect any token in the case of App Check error.
    XCTAssertNil(context.appCheckToken)
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

  func testAsyncContextWithAppCheckWithoutOptionalMethods() async throws {
    let appCheck = AppCheckFakeWithoutOptionalMethods(tokenResult: appCheckTokenSuccess)
    let provider = FunctionsContextProvider(auth: nil, messaging: nil, appCheck: appCheck)

    let context = try await provider.context(options: .init(requireLimitedUseAppCheckTokens: true))

    XCTAssertNil(context.authToken)
    XCTAssertNil(context.fcmToken)
    XCTAssertNil(context.appCheckToken)
    // If the method for limited-use tokens is not implemented, the value should be `nil`:
    XCTAssertNil(context.limitedUseAppCheckToken)
  }

  func testContextWithAppCheckWithoutOptionalMethods() {
    let appCheck = AppCheckFakeWithoutOptionalMethods(tokenResult: appCheckTokenSuccess)
    let provider = FunctionsContextProvider(auth: nil, messaging: nil, appCheck: appCheck)
    let expectation =
      expectation(description: "Verify non-implemented method for limited-use tokens")
    provider.getContext(options: .init(requireLimitedUseAppCheckTokens: true)) { context, error in
      XCTAssertNotNil(context)
      XCTAssertNil(error)
      XCTAssertNil(context.authToken)
      XCTAssertNil(context.fcmToken)
      XCTAssertNil(context.appCheckToken)
      // If the method for limited-use tokens is not implemented, the value should be `nil`:
      XCTAssertNil(context.limitedUseAppCheckToken)
      expectation.fulfill()
    }
    // Importantly, `getContext(options:_:)` must still finish in a timely manner:
    waitForExpectations(timeout: 0.1)
  }

  func testAsyncAllContextsAvailableSuccess() async throws {
    appCheckFake.tokenResult = appCheckTokenSuccess
    let auth = FIRAuthInteropFake(token: "token", userID: "userID", error: nil)
    let provider = FunctionsContextProvider(
      auth: auth,
      messaging: messagingFake,
      appCheck: appCheckFake
    )

    let context = try await provider.context(options: nil)

    XCTAssertEqual(context.authToken, "token")
    XCTAssertEqual(context.fcmToken, messagingFake.fcmToken)
    XCTAssertEqual(context.appCheckToken, appCheckTokenSuccess.token)
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

  func testAsyncAllContextsAuthAndAppCheckError() async {
    appCheckFake.tokenResult = appCheckTokenError
    let authError = NSError(domain: "com.functions.tests", code: 4, userInfo: nil)
    let auth = FIRAuthInteropFake(token: nil, userID: "userID", error: authError)
    let provider = FunctionsContextProvider(
      auth: auth,
      messaging: messagingFake,
      appCheck: appCheckFake
    )

    do {
      _ = try await provider.context(options: nil)
      XCTFail("Expected an error")
    } catch {
      XCTAssertEqual(error as NSError, authError)
    }
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

// MARK: - Utilities

private class AppCheckFakeWithoutOptionalMethods: NSObject, AppCheckInterop {
  let tokenResult: FIRAppCheckTokenResultInterop

  init(tokenResult: FIRAppCheckTokenResultInterop) {
    self.tokenResult = tokenResult
  }

  func getToken(forcingRefresh: Bool, completion handler: @escaping AppCheckTokenHandlerInterop) {
    handler(tokenResult)
  }

  func tokenDidChangeNotificationName() -> String { "AppCheckFakeTokenDidChangeNotification" }
  func notificationTokenKey() -> String { "AppCheckFakeTokenNotificationKey" }
  func notificationAppNameKey() -> String { "AppCheckFakeAppNameNotificationKey" }
}
