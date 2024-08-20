// Copyright 2023 Google LLC
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

#if os(iOS)
  import Foundation
  import XCTest

  @testable import FirebaseAuth

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthAPNSTokenManagerTests: XCTestCase {
    private var fakeApplication: FakeApplication?
    var manager: AuthAPNSTokenManager?
    let data = "qwerty".data(using: .utf8)
    let kRegistrationTimeout = 0.5
    let error = NSError(domain: "dummy", code: 1)

    override func setUp() {
      fakeApplication = FakeApplication()
      manager = AuthAPNSTokenManager(withApplication: fakeApplication!)
    }

    /** @fn testSetToken
        @brief Tests setting and getting the `token` property.
     */
    func testSetToken() throws {
      XCTAssertNil(manager?.token)
      manager?.token = AuthAPNSToken(withData: data!, type: .prod)
      let managerToken = try XCTUnwrap(manager?.token)
      XCTAssertEqual(managerToken.data, data)
      XCTAssertEqual(managerToken.type, .prod)
      manager?.token = nil
      XCTAssertNil(manager?.token)
    }

    /** @fn testDetectTokenType
        @brief Tests automatic detection of token type.
     */
    func testDetectTokenType() throws {
      XCTAssertNil(manager?.token)
      manager?.token = AuthAPNSToken(withData: data!, type: .unknown)
      let managerToken = try XCTUnwrap(manager?.token)
      XCTAssertEqual(managerToken.data, data)
      XCTAssertNotEqual(managerToken.type, .unknown)
    }

    /** @fn testCallback
        @brief Tests callbacks are called.
     */
    func testCallback() throws {
      let expectation = self.expectation(description: #function)
      XCTAssertFalse(fakeApplication!.registerCalled)
      var firstCallbackCalled = false
      let manager = try XCTUnwrap(manager)
      manager.getTokenInternal { result in
        firstCallbackCalled = true
        switch result {
        case let .success(token):
          XCTAssertEqual(token.data, self.data)
          XCTAssertEqual(token.type, .sandbox)
        case let .failure(error):
          XCTFail("Unexpected error: \(error)")
        }
      }
      XCTAssertFalse(firstCallbackCalled)

      // Add second callback, which is yet to be called either.
      var secondCallbackCalled = false
      manager.getTokenInternal { result in
        secondCallbackCalled = true
        switch result {
        case let .success(token):
          XCTAssertEqual(token.data, self.data)
          XCTAssertEqual(token.type, .sandbox)
        case let .failure(error):
          XCTFail("Unexpected error: \(error)")
        }
      }
      XCTAssertFalse(secondCallbackCalled)

      // Setting nil token shouldn't trigger either callbacks.
      manager.token = nil
      XCTAssertFalse(firstCallbackCalled)
      XCTAssertFalse(secondCallbackCalled)
      XCTAssertNil(manager.token)

      // Setting a real token should trigger both callbacks.
      manager.token = AuthAPNSToken(withData: data!, type: .sandbox)
      XCTAssertTrue(firstCallbackCalled)
      XCTAssertTrue(secondCallbackCalled)
      XCTAssertEqual(manager.token?.data, data)
      XCTAssertEqual(manager.token?.type, .sandbox)

      // Add third callback, which should be called back immediately.
      var thirdCallbackCalled = false
      manager.getTokenInternal { result in
        thirdCallbackCalled = true
        switch result {
        case let .success(token):
          XCTAssertEqual(token.data, self.data)
          XCTAssertEqual(token.type, .sandbox)
        case let .failure(error):
          XCTFail("Unexpected error: \(error)")
        }
      }
      XCTAssertTrue(thirdCallbackCalled)

      // In the main thread, Verify the that the fake `registerForRemoteNotifications` was called.
      DispatchQueue.main.async {
        XCTAssertTrue(self.fakeApplication!.registerCalled)
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testTimeout
        @brief Tests callbacks can be timed out.
     */
    func testTimeout() throws {
      // Set up timeout.
      let manager = try XCTUnwrap(manager)
      XCTAssertGreaterThan(try XCTUnwrap(manager.timeout), 0)
      manager.timeout = kRegistrationTimeout

      // Add callback to time out.
      let expectation = self.expectation(description: #function)
      manager.getTokenInternal { result in
        switch result {
        case let .success(token):
          XCTFail("Unexpected success: \(token)")
        case let .failure(error):
          XCTAssertEqual(
            error as NSError,
            AuthErrorUtils.missingAppTokenError(underlyingError: nil) as NSError
          )
        }
        expectation.fulfill()
      }
      // Time out.
      waitForExpectations(timeout: 2)

      // In the main thread, Verify the that the fake `registerForRemoteNotifications` was called.
      let expectation2 = self.expectation(description: "registerCalled")
      DispatchQueue.main.async {
        XCTAssertTrue(self.fakeApplication!.registerCalled)
        expectation2.fulfill()
      }
      // Calling cancel afterwards should have no effect.
      manager.cancel(withError: NSError(domain: "dummy", code: 1))
      waitForExpectations(timeout: 5)
    }

    /** @fn testCancel
        @brief Tests cancelling the pending callbacks.
     */
    func testCancel() throws {
      // Set up timeout.
      let manager = try XCTUnwrap(manager)
      XCTAssertGreaterThan(try XCTUnwrap(manager.timeout), 0)
      manager.timeout = kRegistrationTimeout

      // Add callback to cancel.
      var callbackCalled = false
      manager.getTokenInternal { result in
        switch result {
        case let .success(token):
          XCTFail("Unexpected success: \(token)")
        case let .failure(error):
          XCTAssertEqual(error as NSError, self.error as NSError)
        }
        XCTAssertFalse(callbackCalled) // verify callback is not called twice
        callbackCalled = true
      }
      XCTAssertFalse(callbackCalled)

      // Call cancel.
      manager.cancel(withError: error)

      // In the main thread, Verify the that the fake `registerForRemoteNotifications` was called.
      let expectation2 = expectation(description: "registerCalled")
      DispatchQueue.main.async {
        XCTAssertTrue(self.fakeApplication!.registerCalled)
        expectation2.fulfill()
      }

      // Calling cancel afterwards should have no effect.
      manager.cancel(withError: error)
      waitForExpectations(timeout: 5)
    }

    private class FakeApplication: NSObject, AuthAPNSTokenApplication {
      var registerCalled = false
      func registerForRemoteNotifications() {
        registerCalled = true
      }
    }
  }
#endif
