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

class SettingsUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUp() {
    super.setUp()

    continueAfterFailure = false

    app = XCUIApplication()
    app.launch()
  }

  func testSettings() {
    app.staticTexts["Settings"].tap()

    wait(forElement: app.navigationBars["Settings"], timeout: 5.0)
    XCTAssertTrue(app.navigationBars["Settings"].exists)

    // Test Identity toolkit
    let identityCell = app.cells.containing(.staticText, identifier: "Identity Toolkit").element
    XCTAssertTrue(identityCell.staticTexts["www.googleapis.com"].exists)
    identityCell.tap()
    XCTAssertTrue(identityCell.staticTexts["staging-www.sandbox.googleapis.com"].exists)
    identityCell.tap()
    XCTAssertTrue(identityCell.staticTexts["www.googleapis.com"].exists)

    // Test Secure Token
    let secureTokenCell = app.cells.containing(.staticText, identifier: "Secure Token").element
    XCTAssertTrue(secureTokenCell.staticTexts["securetoken.googleapis.com"].exists)
    secureTokenCell.tap()
    XCTAssertTrue(secureTokenCell.staticTexts["staging-securetoken.sandbox.googleapis.com"].exists)
    secureTokenCell.tap()
    XCTAssertTrue(secureTokenCell.staticTexts["securetoken.googleapis.com"].exists)

    // Swap Firebase App
    let appCell = app.cells.containing(.staticText, identifier: "Active App").element
    XCTAssertTrue(appCell.staticTexts["fir-ios-auth-sample"].exists)
    appCell.tap()
    XCTAssertTrue(appCell.staticTexts["fb-sa-upgraded"].exists)
    appCell.tap()
    XCTAssertTrue(appCell.staticTexts["fir-ios-auth-sample"].exists)

    // Current Access Group
    let accessCell = app.cells.containing(.staticText, identifier: "Current Access Group").element
    XCTAssertTrue(accessCell.staticTexts["[none]"].exists)
    // TODO: Debug why the following works locally but crashes app in GitHub Actions.
//    accessCell.tap()
//    let predicate = NSPredicate(format: "label CONTAINS
//    'com.google.firebase.auth.keychainGroup1'")
//    let createAccountText = accessCell.staticTexts.containing(predicate).element.exists
//    accessCell.tap()
//    XCTAssertTrue(accessCell.staticTexts["[none]"].exists)

    // Auth Language
    let languageCell = app.cells.containing(.staticText, identifier: "Auth Language").element
    XCTAssertTrue(languageCell.staticTexts["[none]"].exists)
    languageCell.tap()
    app.typeText("abc")
    app.buttons["OK"].tap()
    XCTAssertTrue(languageCell.staticTexts["abc"].exists)

    // TODO: PhoneAuth

    // Click to Use App Language
    let appLanguageCell = app.cells.containing(.staticText,
                                               identifier: "Click to Use App Language").element
    appLanguageCell.tap()
    // Check for either Xcode 14 or Xcode 15 strings.
    XCTAssertTrue(languageCell.staticTexts["en"].exists || languageCell.staticTexts["en-US"].exists)

    // Disable App Verification
    let disabledCell = app.cells.containing(.staticText,
                                            identifier: "Disable App Verification (Phone)")
      .element
    XCTAssertTrue(disabledCell.staticTexts["NO"].exists, "App verification should NOT be disabled")
    disabledCell.tap()
    XCTAssertTrue(disabledCell.staticTexts["YES"].exists, "App verification should NOW be disabled")
    disabledCell.tap()
    XCTAssertTrue(disabledCell.staticTexts["NO"].exists, "App verification should NOT be disabled")
  }
}
