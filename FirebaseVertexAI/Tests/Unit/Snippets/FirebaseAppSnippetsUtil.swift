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
  // These snippets are not invoked in CI but may be run manually by placing a
  // GoogleService-Info.plist in the the FirebaseVertexAI/Tests/Unit/Resources folder.
  static func configureForSnippets() throws {
    guard let plistPath = Bundle.module.path(
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
}
