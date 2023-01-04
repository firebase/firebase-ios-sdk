/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// macOS requests a user password when accessing the Keychain for the first time,
// so the tests may fail. Disable integration tests on macOS so far.
// TODO: Configure the tests to run on macOS without requesting the keychain password.
#if !os(OSX)
  import FirebaseCore
  import FirebaseMessaging
  import XCTest

  // This class should be only used once to ensure the test is independent
  class fakeAppDelegate: NSObject, MessagingDelegate {
    var messaging = Messaging.messaging()
    var delegateIsCalled = false

    func messaging(_: Messaging, didReceiveRegistrationToken _: String?) {
      delegateIsCalled = true
    }
  }

  class FIRMessagingTokenRefreshTests: XCTestCase {
    var app: FirebaseApp!
    var messaging: Messaging!

    override class func setUp() {
      if FirebaseApp.app() == nil {
        FirebaseApp.configure()
      }
    }

    override func setUpWithError() throws {
      messaging = try XCTUnwrap(Messaging.messaging())
      // fake APNS Token
      messaging.apnsToken = "eb706b132b2f9270faac751e4ceab283f1803b729ac1dd399db3fd2a98bb101b"
        .data(using: .utf8)
    }

    override func tearDown() {
      messaging = nil
    }

    func testDeleteTokenWithTokenRefreshDelegatesAndNotifications() {
      let expectation = self.expectation(description: "delegate method and notification are called")
      assertTokenWithAuthorizedEntity()

      let notificationExpectation = self.expectation(forNotification: NSNotification.Name
        .MessagingRegistrationTokenRefreshed,
        object: nil,
        handler: nil)

      let testDelegate = fakeAppDelegate()
      messaging.delegate = testDelegate
      testDelegate.delegateIsCalled = false

      messaging.deleteFCMToken(forSenderID: tokenAuthorizedEntity(), completion: { error in
        XCTAssertNil(error)
        XCTAssertTrue(testDelegate.delegateIsCalled)
        expectation.fulfill()
      })
      wait(for: [expectation, notificationExpectation], timeout: 5)
    }

    func testDeleteDefaultTokenWithTokenRefreshDelegatesAndNotifications() {
      let expectation = self.expectation(description: "delegate method and notification are called")
      assertDefaultToken()

      let notificationExpectation = self.expectation(forNotification: NSNotification.Name
        .MessagingRegistrationTokenRefreshed,
        object: nil,
        handler: nil)

      let testDelegate = fakeAppDelegate()
      messaging?.delegate = testDelegate
      testDelegate.delegateIsCalled = false
      messaging.deleteToken { error in
        XCTAssertNil(error)
        XCTAssertTrue(testDelegate.delegateIsCalled)
        expectation.fulfill()
      }
      wait(for: [expectation, notificationExpectation], timeout: 5)
    }

    func testDeleteDataWithTokenRefreshDelegatesAndNotifications() {
      let expectation = self.expectation(description: "delegate method and notification are called")
      assertDefaultToken()

      let notificationExpectation = self.expectation(forNotification: NSNotification.Name
        .MessagingRegistrationTokenRefreshed,
        object: nil,
        handler: nil)

      let testDelegate = fakeAppDelegate()
      messaging?.delegate = testDelegate
      testDelegate.delegateIsCalled = false

      messaging.deleteData { error in
        XCTAssertNil(error)
        XCTAssertTrue(testDelegate.delegateIsCalled)
        expectation.fulfill()
      }
      wait(for: [expectation, notificationExpectation], timeout: 5)
    }

    // pragma mark - Helpers
    func assertTokenWithAuthorizedEntity() {
      let expectation = self.expectation(description: "tokenWithAuthorizedEntity")

      messaging.retrieveFCMToken(forSenderID: tokenAuthorizedEntity()) { token, error in
        XCTAssertNil(error)
        XCTAssertNotNil(token)
        expectation.fulfill()
      }
      wait(for: [expectation], timeout: 5)
    }

    func assertDefaultToken() {
      let expectation = self.expectation(description: "getToken")

      messaging.token { token, error in
        XCTAssertNil(error)
        XCTAssertNotNil(token)
        expectation.fulfill()
      }
      wait(for: [expectation], timeout: 5)
    }

    func tokenAuthorizedEntity() -> String {
      guard let app = FirebaseApp.app() else {
        return ""
      }
      return app.options.gcmSenderID
    }
  }
#endif // !TARGET_OS_OSX
