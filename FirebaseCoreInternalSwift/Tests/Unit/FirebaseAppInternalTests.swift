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
@testable import FirebaseCoreInternalSwift

class FirebaseAppTests: XCTestCase {
  #if compiler(>=5.5) && canImport(_Concurrency)

    // MARK: - Configuration

    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testIsConfigured() async throws {
      XCTAssertFalse(FirebaseApp.isDefaultAppConfigured)
      FirebaseApp.configure(options: .fakeOptions)
      XCTAssertTrue(FirebaseApp.isDefaultAppConfigured)

      // Clean up and delete the default app we just configured.
      let app = try XCTUnwrap(FirebaseApp.app())
      let deleted = await app.delete()
      XCTAssertTrue(deleted)
    }

    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func testIsDefaultApp() async throws {
      // Configure the default app.
      FirebaseApp.configure(options: .fakeOptions)
      let defaultApp = try XCTUnwrap(FirebaseApp.app())
      XCTAssertTrue(defaultApp.isDefaultApp)

      // Clean up the default app.
      let defaultAppDeleted = await defaultApp.delete()
      XCTAssertTrue(defaultAppDeleted)

      // Configure a custom named app.
      FirebaseApp.configure(name: "CUSTOM", options: .fakeOptions)
      let customApp = try XCTUnwrap(FirebaseApp.app(name: "CUSTOM"))
      XCTAssertFalse(customApp.isDefaultApp)

      // Clean up the custom app.
      let customAppDeleted = await customApp.delete()
      XCTAssertTrue(customAppDeleted)
    }

  #else
    // Signal that the above tests were skipped.
    func testIsConfigured() { XCTSkip("This test uses async/await") }
    func testIsDefaultApp() { XCTSkip("This test uses async/await") }
  #endif // #if compiler(>=5.5) && canImport(_Concurrency)

  // MARK: - Initialization

  func testAppInit() {
    let appName = "my_custom_app"
    let app = FirebaseApp.initializedApp(name: appName, options: .fakeOptions)
    XCTAssertEqual(app.name, appName)
    XCTAssertEqual(app.options, FirebaseOptions.fakeOptions)

    // The app shouldn't have been added to the app dictionary.
    XCTAssertNil(FirebaseApp.app(name: appName))

    // The default app shouldn't be initialized.
    XCTAssertNil(FirebaseApp.app())

    // No need to delete the instance since it wasn't added to the apps dictionary.
  }
}

private extension FirebaseOptions {
  /// An fake instance of options for test purposes.
  static let fakeOptions: FirebaseOptions = {
    FirebaseOptions(googleAppID: "1:123:ios:123abc", gcmSenderID: "fake-gcm-sender-id")
  }()
}
