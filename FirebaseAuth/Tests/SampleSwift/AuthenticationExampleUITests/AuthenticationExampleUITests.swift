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

  func testPhoneMultiFactorEnrollUnenroll() {
    // login with email password
    app.staticTexts["Email & Password Login"].tap()
    let testEmail = "sample.auth.ios@gmail.com"
    app.textFields["Email"].tap()
    app.typeText(testEmail)
    let testPassword = "sampleauthios"
    app.textFields["Password"].tap()
    app.typeText(testPassword)
    app.buttons["Login"].tap()
    // enroll multifactor with phone
    let authenticationButton = app.tabBars.buttons["Authentication"]
    let exists = authenticationButton.waitForExistence(timeout: 5)
    XCTAssertTrue(exists, "Authentication button did not appear in time.")
    authenticationButton.tap()
    app.tables.cells.staticTexts["Phone Enroll"].tap()
    let testSecondFactorPhone = "+11234567890"
    app.typeText(testSecondFactorPhone)
    app.buttons["Save"].tap()
    let testVerificationCode = "123456"
    app.typeText(testVerificationCode)
    app.buttons["Save"].tap()
    let testPhoneSecondFactorDisplayName = "phone1"
    app.typeText(testPhoneSecondFactorDisplayName)
    app.buttons["Save"].tap()
    // unenroll multifactor
    app.swipeUp(velocity: .fast)
    app.tables.cells.staticTexts["Multifactor unenroll"].tap()
    XCTAssertTrue(app.buttons["phone1"].exists) // enrollment successful
    app.buttons["phone1"].tap()
    app.swipeUp(velocity: .fast)
    app.tables.cells.staticTexts["Multifactor unenroll"].tap()
    XCTAssertFalse(app.buttons["phone1"].exists) // unenrollment successful
    app.buttons["Cancel"].tap()
    // sign out after unenroll
    app.tabBars.buttons["Current User"].tap()
    app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
  }

  func testPhoneSecondFactorSignIn() {
    // login with email password
    app.staticTexts["Email & Password Login"].tap()
    let testEmail = "sample.ios.auth@gmail.com"
    app.textFields["Email"].tap()
    app.typeText(testEmail)
    let testPassword = "sampleios123"
    app.textFields["Password"].tap()
    app.typeText(testPassword)
    app.buttons["Login"].tap()
    // login with second factor
    XCTAssertTrue(app.staticTexts["Choose a second factor to continue."]
      .waitForExistence(timeout: 5))
    let secondFactor = app.staticTexts["phone2"] // select 'phone2' as second factor
    XCTAssertTrue(secondFactor.exists, "'phone2' option should be visible.")
    secondFactor.tap()
    app.buttons["Send Verification Code"].tap()
    let verificationCodeInput = app.textFields["Enter verification code."]
    verificationCodeInput.tap()
    let testVerificationCode = "123456"
    verificationCodeInput.typeText(testVerificationCode)
    let signInButton = app.buttons["Sign in"]
    XCTAssertTrue(signInButton.waitForExistence(timeout: 2), "'Sign in' button should be visible.")
    signInButton.tap()
    // sign out
    let signOutButton = app.buttons["Sign Out"]
    if signOutButton.exists {
      signOutButton.tap()
    }
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
