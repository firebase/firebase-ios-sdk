// Copyright 2024 Google LLC
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

import FirebaseCore
import Foundation
import XCTest

extension FirebaseApp {
  /// Configures the default `FirebaseApp` for use in snippets tests.
  ///
  /// Uses a `GoogleService-Info.plist` file from the
  /// [`Resources`](https://github.com/firebase/firebase-ios-sdk/tree/main/FirebaseVertexAI/Tests/Unit/Resources)
  /// directory.
  ///
  /// > Note: This is typically called in a snippet test's set up; overriding
  /// > `setUpWithError() throws` works well since it supports throwing errors.
  static func configureDefaultAppForSnippets() throws {
    guard let plistPath = BundleTestUtil.bundle().path(
      forResource: "GoogleService-Info",
      ofType: "plist"
    ) else {
      throw XCTSkip("No GoogleService-Info.plist found in FirebaseVertexAI/Tests/Unit/Resources.")
    }

    let options = try XCTUnwrap(FirebaseOptions(contentsOfFile: plistPath))
    FirebaseApp.configure(options: options)

    guard FirebaseApp.isDefaultAppConfigured() else {
      XCTFail("Default Firebase app not configured.")
      return
    }
  }

  /// Deletes the default `FirebaseApp` if configured.
  ///
  /// > Note: This is typically called in a snippet test's tear down; overriding
  /// > `tearDown() async throws` works well since deletion is asynchronous.
  static func deleteDefaultAppForSnippets() async {
    // Checking if `isDefaultAppConfigured()` before calling `FirebaseApp.app()` suppresses a log
    // message that "The default Firebase app has not yet been configured." during `tearDown` when
    // the tests are skipped. This reduces extraneous noise in the test logs.
    if FirebaseApp.isDefaultAppConfigured(), let app = FirebaseApp.app() {
      await app.delete()
    }
  }
}
