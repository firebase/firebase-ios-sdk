// Copyright 2020 Google LLC
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

class AuthenticationExampleUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUp() {
    super.setUp()

    continueAfterFailure = false

    app = XCUIApplication()
    app.launch()
  }

  override func tearDown() {
    super.tearDown()
    signOut()
  }

  func testAuth() {
    // Verify that Auth Example app launched successfully
    XCTAssertTrue(app.navigationBars["Firebase Auth"].exists)
  }

  func testAuthAnonymously() {
    app.staticTexts["Anonymous Authentication"].tap()

    wait(forElement: app.navigationBars["User"], timeout: 5.0)
    XCTAssertTrue(app.navigationBars["User"].exists)

    let isAnonymousCell = app.cells.containing(.staticText, identifier: "Is User Anonymous?")
      .element
    XCTAssertTrue(isAnonymousCell.staticTexts["Yes"].exists, "The user should be anonymous")
  }

  func testAuthExistingAccount() {
    // Setup existing user for duplicate test below.
    let existingEmail = "existing@test.com"
    let existingPassword = "existingPW"

    app.staticTexts["Email & Password Login"].tap()

    let testEmail = existingEmail
    app.textFields["Email"].tap()
    app.textFields["Email"].typeText(testEmail)

    let testPassword = existingPassword
    app.textFields["Password"].tap()
    app.textFields["Password"].typeText(testPassword)

    app.buttons["Login"].tap()

    wait(forElement: app.navigationBars["User"], timeout: 5.0)
    XCTAssertTrue(app.navigationBars["User"].exists)
    XCTAssertTrue(
      app.staticTexts[testEmail].exists,
      "The user should be signed in and the email field should display their email."
    )
  }

  func testAuthExistingAccountWrongPassword() {
    app.staticTexts["Email & Password Login"].tap()

    let testEmail = "test@test.com"
    app.textFields["Email"].tap()
    app.textFields["Email"].typeText(testEmail)

    app.textFields["Password"].tap()
    app.textFields["Password"].typeText("wrong password")

    app.buttons["Login"].tap()

    wait(forElement: app.alerts.staticTexts["Error"], timeout: 5.0)
    XCTAssertTrue(app.alerts.staticTexts["Error"].exists)

    // Dismiss alert that password was incorrect
    app.alerts.buttons["OK"].tap()

    // Go back and check that there is no user that is signed in
    app.navigationBars.buttons.firstMatch.tap()
    app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
    wait(forElement: app.navigationBars["User"], timeout: 5.0)
    XCTAssertEqual(
      app.cells.count,
      0,
      "The user shouldn't be signed in and the user view should have no cells."
    )
  }

  func testCreateAccountBadPassword() {
    app.staticTexts["Email & Password Login"].tap()

    let testEmail = "test@test.com"
    app.textFields["Email"].tap()
    app.textFields["Email"].typeText(testEmail)

    app.textFields["Password"].tap()
    // Enter an invalid password that is "too short"
    app.textFields["Password"].typeText("2shrt")

    app.buttons["Create Account"].tap()

    wait(forElement: app.alerts.staticTexts["Error"], timeout: 5.0)
    XCTAssertTrue(app.alerts.staticTexts["Error"].exists)

    // Dismiss alert that password was incorrect
    app.alerts.buttons["OK"].tap()

    // Go back and check that there is no user that is signed in
    app.navigationBars.buttons.firstMatch.tap()
    app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
    wait(forElement: app.navigationBars["User"], timeout: 5.0)
    XCTAssertEqual(
      app.cells.count,
      0,
      "The user shouldn't be signed in and the user view should have no cells."
    )
  }

  func testCreateAlreadyExistingAccount() {
    app.staticTexts["Email & Password Login"].tap()

    let testEmail = "test@test.com"
    app.textFields["Email"].tap()
    app.textFields["Email"].typeText(testEmail)

    let testPassword = "test12"
    app.textFields["Password"].tap()
    app.textFields["Password"].typeText(testPassword)

    app.buttons["Create Account"].tap()

    wait(forElement: app.alerts.staticTexts["Error"], timeout: 5.0)
    XCTAssertTrue(app.alerts.staticTexts["Error"].exists)

    // Dismiss alert that password was incorrect
    app.alerts.buttons["OK"].tap()

    // Go back and check that there is no user that is signed in
    app.navigationBars.buttons.firstMatch.tap()
    app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
    wait(forElement: app.navigationBars["User"], timeout: 5.0)
    XCTAssertEqual(
      app.cells.count,
      0,
      "The user shouldn't be signed in and the user view should have no cells."
    )
  }

  func testCreateAccountCorrectPassword() {
    app.staticTexts["Email & Password Login"].tap()

    let newEmail = "\(Date().timeIntervalSince1970)_test@test.com"
    app.textFields["Email"].tap()
    app.typeText(newEmail)

    let newPassword = "new password"
    app.textFields["Password"].tap()
    app.typeText(newPassword)

    app.buttons["Create Account"].tap()

    wait(forElement: app.navigationBars["User"], timeout: 5.0)
    XCTAssertTrue(app.navigationBars["User"].exists)
    XCTAssertTrue(
      app.staticTexts[newEmail].exists,
      "The user should be signed into the new account."
    )
  }

  func DRAFT_testGoogleSignInAndLinkAccount() {
    let interruptionMonitor = addUIInterruptionMonitor(withDescription: "Sign in with Google") {
      alert -> Bool in
      alert.buttons["Continue"].tap()
      return true
    }

    app.staticTexts["Google"].tap()

    app.tap() // Triggers the UIInterruptionMonitor

    let testEmail = ""
    let testPassword = ""

    let firstTimeLogin = app.webViews.containing(.textField, identifier: "Email or phone")
      .element.exists
    if firstTimeLogin {
      app.webViews.textFields.firstMatch.tap()

      app.webViews.textFields.firstMatch.typeText(testEmail)

      app.buttons["Done"].tap() // Dismiss keyboard
      app.buttons["Next"].tap() // Transition to Google sign in password page

      app.webViews.secureTextFields.firstMatch.tap()

      app.webViews.secureTextFields.firstMatch.typeText(testPassword)

      app.buttons["Done"].tap() // Dismiss keyboard
      app.buttons["Next"].tap() // Complete sign in

    } else {
      app.webViews.staticTexts[testEmail].tap()
    }

    wait(forElement: app.navigationBars["User"], timeout: 5.0)

    XCTAssertTrue(app.navigationBars["User"].exists)
    XCTAssertTrue(app.staticTexts[testEmail].exists)

    // Cleanup
    removeUIInterruptionMonitor(interruptionMonitor)
  }

  // MARK: - Private Helpers

  private func signOut() {
    if app.tabBars.firstMatch.buttons.element(boundBy: 1).exists {
      app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
    }
    wait(forElement: app.navigationBars["User"], timeout: 5.0)
    if app.staticTexts["Sign Out"].exists {
      app.staticTexts["Sign Out"].tap()
    }
    if app.tabBars.firstMatch.buttons.element(boundBy: 0).exists {
      app.tabBars.firstMatch.buttons.element(boundBy: 0).tap()
    }
  }
}

extension XCTestCase {
  func wait(forElement element: XCUIElement, timeout: TimeInterval) {
    let predicate = NSPredicate(format: "exists == 1")
    expectation(for: predicate, evaluatedWith: element)
    waitForExpectations(timeout: timeout)
  }
}
