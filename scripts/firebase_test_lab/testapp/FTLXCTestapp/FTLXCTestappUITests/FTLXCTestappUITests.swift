/*
 * Copyright 2022 Google LLC
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

import XCTest

class FTLXCTestappUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {}

  func testExample() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssert(app.staticTexts["Hello, world!"].exists)
  }

  func testFailedExample() throws {
    let app = XCUIApplication()
    app.launch()

    // Set the test to fail intentionally to test failed test cases on FTL.
    XCTAssert(app.staticTexts["No Exsited"].exists)
  }
}
