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

import XCTest
import FirebaseCore
@testable import FirebaseCoreSwift

class FirebaseAppTests: XCTestCase {
  // MARK: - Configuration

  func testIsConfigured() async throws {
    XCTAssertFalse(FirebaseApp.isDefaultAppConfigured)
    FirebaseApp.configure(options: FirebaseOptions(googleAppID: "1:123:ios:123abc",
                                                   gcmSenderID: "fake-gcm-sender-id"))
    XCTAssertTrue(FirebaseApp.isDefaultAppConfigured)

    // Clean up and delete the default app we just configured.
    let app = try XCTUnwrap(FirebaseApp.app())
    let deleted = await app.delete()
    XCTAssertTrue(deleted)
  }

  func testIsDefaultApp() async throws {
    // Configure the default app.
    FirebaseApp.configure(options: FirebaseOptions(googleAppID: "1:123:ios:123abc",
                                                   gcmSenderID: "fake-gcm-sender-id"))
    let defaultApp = try XCTUnwrap(FirebaseApp.app())
    XCTAssertTrue(defaultApp.isDefaultApp)

    // Clean up the default app.
    let defaultAppDeleted = await defaultApp.delete()
    XCTAssertTrue(defaultAppDeleted)

    // Configure a custom named app.
    FirebaseApp.configure(name: "CUSTOM",
                          options: FirebaseOptions(googleAppID: "1:321:ios:321cba",
                                                   gcmSenderID: "fake-gcm-sender-id2"))
    let customApp = try XCTUnwrap(FirebaseApp.app(name: "CUSTOM"))
    XCTAssertFalse(customApp.isDefaultApp)

    // Clean up the custom app.
    let customAppDeleted = await customApp.delete()
    XCTAssertTrue(customAppDeleted)
  }

  // MARK: - Firebase User Agent

  func testRegisterLibrary() {
    let libName = "testing"
    let libVersion = "1.2.3"
    let agent = FirebaseApp.firebaseUserAgent()
    XCTAssertFalse(agent.contains("\(libName):\(libVersion)"))

    // Register the library and verify it's in the new user agent split by a `/`.
    FirebaseApp.registerLibrary(name: libName, version: libVersion)
    let newAgent = FirebaseApp.firebaseUserAgent()
    XCTAssertTrue(newAgent.contains("\(libName)/\(libVersion)"))
  }
}
