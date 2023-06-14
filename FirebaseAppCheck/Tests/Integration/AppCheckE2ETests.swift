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

import XCTest

import FirebaseAppCheck
import FirebaseCore

final class AppCheckE2ETests: XCTestCase {
  // TODO(andrewheard): Add integration tests that exercise the public API.

  let appName = "test_app_name"
  var app: FirebaseApp!

  override func setUpWithError() throws {
    let options = FirebaseOptions(googleAppID: "1:123456789:ios:abc123", gcmSenderID: "123456789")
    options.projectID = "test_project_id"
    options.apiKey = "test_api_key"
    FirebaseApp.configure(name: appName, options: options)

    app = FirebaseApp.app(name: appName)
  }

  override func tearDown() async throws {
    await app.delete()
  }

  func testInitAppCheck() throws {
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    let appCheck = AppCheck.appCheck(app: app)

    XCTAssertNotNil(appCheck)
  }

  func testInitAppCheckDebugProvider() throws {
    let debugProvider = AppCheckDebugProvider(app: app)

    XCTAssertNotNil(debugProvider)
  }
}
