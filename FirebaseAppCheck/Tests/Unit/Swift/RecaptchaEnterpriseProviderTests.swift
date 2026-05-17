// Copyright 2026 Google LLC
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

import AppCheckCore
import AppCheckRecaptchaEnterpriseProvider
import FirebaseAppCheck
import FirebaseCore
import ObjectiveC
import RecaptchaInterop
import XCTest

// These stub classes are needed to satisfy the reflection checks in
// AppCheckRecaptchaEnterpriseProvider.swift in the app-check repository.
// That class uses NSClassFromString to check if the Recaptcha Enterprise SDK
// is linked. By providing these stub classes with the expected Objective-C names
// using the runtime, we can run unit tests without crashing.

final class StubRCAAction: NSObject, RCAActionProtocol {
  static var login: RCAActionProtocol { fatalError("Not implemented") }
  static var signup: RCAActionProtocol { fatalError("Not implemented") }

  var action: String

  required init(customAction: String) {
    action = customAction
    super.init()
  }
}

final class StubRCARecaptcha: NSObject, RCARecaptchaProtocol {
  // Add a placeholder initializer to prevent inheriting init() from NSObject,
  // which conflicts with the unavailable init in RCARecaptchaProtocol.
  init(placeholder: Void) {
    super.init()
  }

  static func fetchClient(withSiteKey siteKey: String,
                          completion: @escaping (RCARecaptchaClientProtocol?, Error?) -> Void) {
    // Do nothing.
  }
}

let registerMocksOnce: Void = {
  let actionClass = objc_allocateClassPair(StubRCAAction.self, "RecaptchaEnterprise.RCAAction", 0)
  if let actionClass = actionClass {
    objc_registerClassPair(actionClass)
  }

  let recaptchaClass = objc_allocateClassPair(
    StubRCARecaptcha.self,
    "RecaptchaEnterprise.RCARecaptcha",
    0
  )
  if let recaptchaClass = recaptchaClass {
    objc_registerClassPair(recaptchaClass)
  }
}()

class FakeInternalProvider: NSObject, AppCheckCoreProvider {
  var stubbedToken: AppCheckCoreToken?
  var stubbedError: Error?

  @objc(getTokenWithCompletion:)
  func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    handler(stubbedToken, stubbedError)
  }

  @objc(getLimitedUseTokenWithCompletion:)
  func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    handler(stubbedToken, stubbedError)
  }
}

final class RecaptchaEnterpriseProviderTests: XCTestCase {
  var provider: RecaptchaEnterpriseProvider!
  var fakeInternalProvider: FakeInternalProvider!

  override func setUp() {
    super.setUp()
    _ = registerMocksOnce
    fakeInternalProvider = FakeInternalProvider()

    guard let ProviderClass = NSClassFromString("FIRRecaptchaEnterpriseProvider") as? NSObject.Type
    else {
      XCTFail("Failed to get FIRRecaptchaEnterpriseProvider class")
      return
    }

    let providerInstance = ProviderClass.init()
    providerInstance.setValue(fakeInternalProvider, forKey: "recaptchaEnterpriseProvider")

    guard let typedProvider = providerInstance as? RecaptchaEnterpriseProvider else {
      XCTFail("Failed to cast provider instance to RecaptchaEnterpriseProvider")
      return
    }

    provider = typedProvider
  }

  override func tearDown() {
    provider = nil
    fakeInternalProvider = nil
    super.tearDown()
  }

  func testInitWithValidApp() {
    let options = FirebaseOptions(googleAppID: "1:123456789:ios:abc123", gcmSenderID: "sender_id")
    options.apiKey = "api_key"
    options.projectID = "project_id"

    let appName = "testInitWithValidApp"
    let app: FirebaseApp
    if let existingApp = FirebaseApp.app(name: appName) {
      app = existingApp
    } else {
      FirebaseApp.configure(name: appName, options: options)
      app = FirebaseApp.app(name: appName)!
    }
    app.isDataCollectionDefaultEnabled = false

    XCTAssertNotNil(RecaptchaEnterpriseProvider(app: app, siteKey: "test_site_key"))
  }

  func testInitWithIncompleteApp() {
    let options = FirebaseOptions(googleAppID: "1:123456789:ios:abc123", gcmSenderID: "sender_id")
    options.projectID = "project_id"

    let appName = "testInitWithIncompleteApp1"
    let missingAPIKeyApp: FirebaseApp
    if let existingApp = FirebaseApp.app(name: appName) {
      missingAPIKeyApp = existingApp
    } else {
      FirebaseApp.configure(name: appName, options: options)
      missingAPIKeyApp = FirebaseApp.app(name: appName)!
    }
    missingAPIKeyApp.isDataCollectionDefaultEnabled = false

    XCTAssertNil(RecaptchaEnterpriseProvider(app: missingAPIKeyApp, siteKey: "test_site_key"))

    options.projectID = nil
    options.apiKey = "api_key"

    let appName2 = "testInitWithIncompleteApp2"
    let missingProjectIDApp: FirebaseApp
    if let existingApp = FirebaseApp.app(name: appName2) {
      missingProjectIDApp = existingApp
    } else {
      FirebaseApp.configure(name: appName2, options: options)
      missingProjectIDApp = FirebaseApp.app(name: appName2)!
    }
    missingProjectIDApp.isDataCollectionDefaultEnabled = false
    XCTAssertNil(RecaptchaEnterpriseProvider(app: missingProjectIDApp, siteKey: "test_site_key"))
  }

  func testGetTokenSuccess() {
    let date = Date()
    let validInternalToken = AppCheckCoreToken(
      token: "valid_token",
      expirationDate: date,
      receivedAt: date
    )
    fakeInternalProvider.stubbedToken = validInternalToken

    let expectation = self.expectation(description: "getToken")

    provider.getToken { token, error in
      XCTAssertEqual(token?.token, validInternalToken.token)
      XCTAssertEqual(token?.expirationDate, validInternalToken.expirationDate)
      XCTAssertNil(error)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1, handler: nil)
  }

  func testGetTokenAPIError() {
    let expectedError = NSError(domain: "testGetTokenAPIError", code: -1, userInfo: nil)
    fakeInternalProvider.stubbedError = expectedError

    let expectation = self.expectation(description: "getTokenError")

    provider.getToken { token, error in
      XCTAssertNil(token)
      XCTAssertEqual(error as NSError?, expectedError)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1, handler: nil)
  }

  func testGetLimitedUseTokenSuccess() {
    let date = Date()
    let validInternalToken = AppCheckCoreToken(
      token: "TEST_ValidToken",
      expirationDate: date,
      receivedAt: date
    )
    fakeInternalProvider.stubbedToken = validInternalToken

    let expectation = self.expectation(description: "getLimitedUseToken")

    provider.getLimitedUseToken { token, error in
      XCTAssertEqual(token?.token, validInternalToken.token)
      XCTAssertEqual(token?.expirationDate, validInternalToken.expirationDate)
      XCTAssertNil(error)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1, handler: nil)
  }

  func testGetLimitedUseTokenProviderError() {
    let expectedError = NSError(domain: "TEST_LimitedUseToken_Error", code: -1, userInfo: nil)
    fakeInternalProvider.stubbedError = expectedError

    let expectation = self.expectation(description: "getLimitedUseTokenError")

    provider.getLimitedUseToken { token, error in
      XCTAssertNil(token)
      XCTAssertEqual(error as NSError?, expectedError)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1, handler: nil)
  }
}
