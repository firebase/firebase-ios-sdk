/*
 * Copyright 2021 Google LLC
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

  class FIRMessagingPubSubTest: XCTestCase {
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

    func testSubscribeTopic() {
      let expectation = self.expectation(description: "Successfully subscribe topic")
      assertDefaultToken()

      messaging.subscribe(toTopic: "cat_video") { error in
        XCTAssertNil(error)
        expectation.fulfill()
      }
      wait(for: [expectation], timeout: 5)
    }

    func testUnsubscribeTopic() {
      let expectation = self.expectation(description: "Successfully unsubscribe topic")
      assertDefaultToken()

      messaging.unsubscribe(fromTopic: "cat_video") { error in
        XCTAssertNil(error)
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
  }
#endif // !TARGET_OS_OSX
