//
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

final class UITestsiOS: XCTestCase {
  func test_sessionGenerated_onColdStart() throws {
    // UI tests must launch the application that they test.
    let app = XCUIApplication()

    // Collect necessary environment variables and propagate them as necessary
    let environment = ProcessInfo.processInfo.environment["FirebaseSessionsRunEnvironment"]
    if environment != nil {
      let variables = ["FirebaseSessionsRunEnvironment": environment!]
      app.launchEnvironment = variables
    }

    app.launch()
    XCUIDevice.shared.press(.home)
    app.activate()

    // Use XCTAssert and related functions to verify your tests produce the correct results.
  }
}
