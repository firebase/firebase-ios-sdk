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

import Foundation
import XCTest

@testable import FirebaseAuth
import FirebaseCore

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthLifecycleTests: XCTestCase {
  private let kFakeAPIKey = "FAKE_API_KEY"
  private let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                        gcmSenderID: "00000000000000000-00000000000-000000000")

  override func setUp() {
    options.apiKey = kFakeAPIKey
    FirebaseApp.resetApps()
    FirebaseApp.configure(options: options)
  }

  /** @fn testSingleton
      @brief Verifies the @c auth method behaves like a singleton.
   */
  func testSingleton() {
    let auth1 = Auth.auth()
    XCTAssertNotNil(auth1)
    let auth2 = Auth.auth()
    XCTAssertTrue(auth1 === auth2)
  }

  /** @fn testDefaultAuth
      @brief Verifies the @c auth method associates with the default Firebase app.
   */
  func testDefaultAuth() throws {
    let auth1 = Auth.auth()
    let defaultApp = try XCTUnwrap(FirebaseApp.app())
    let auth2 = Auth.auth(app: defaultApp)
    XCTAssertTrue(auth1 === auth2)
    XCTAssertTrue(auth1.app === defaultApp)
  }

  /** @fn testAppAPIkey
      @brief Verifies the API key is correctly copied from @c FIRApp to @c FIRAuth .
   */
  func testAppAPIKey() {
    let auth = Auth.auth()
    XCTAssertEqual(auth.requestConfiguration.apiKey, kFakeAPIKey)
  }

  /** @fn testAppAssociation
      @brief Verifies each @c FIRApp instance associates with a @c FIRAuth .
   */
  func testAppAssociation() throws {
    let app1 = FirebaseApp(instanceWithName: "app1", options: options)
    let auth1 = Auth(app: app1)
    XCTAssertNotNil(auth1)
    XCTAssertEqual(auth1.app, app1)

    let app2 = FirebaseApp(instanceWithName: "app2", options: options)
    let auth2 = Auth(app: app2)
    XCTAssertNotNil(auth2)
    XCTAssertEqual(auth2.app, app2)

    XCTAssert(auth1 !== auth2)
  }

  /** @fn testLifeCycle
      @brief Verifies the life cycle of @c FIRAuth is the same as its associated @c FIRApp .
   */
  func testLifecycle() {
    let expectation = self.expectation(description: #function)
    weak var app: FirebaseApp?
    weak var auth: Auth?
    autoreleasepool {
      let app1 = FirebaseApp(instanceWithName: "app1", options: options)
      app = app1
      let auth1 = Auth(app: app1)
      auth = auth1
      // Verify that neither the app nor the auth is released yet, i.e., the app owns the auth
      // because nothing else retains the auth.
      XCTAssertNotNil(app)
      XCTAssertNotNil(auth)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      XCTAssertNil(app)
      XCTAssertNil(auth)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }
}
