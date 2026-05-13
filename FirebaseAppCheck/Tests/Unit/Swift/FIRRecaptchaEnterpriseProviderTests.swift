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
@testable import FirebaseAppCheck
import FirebaseCore
import RecaptchaEnterpriseProvider
import XCTest

class FakeGACRecaptchaEnterpriseProvider: GACRecaptchaEnterpriseProvider {
  var stubbedToken: GACAppCheckToken?
  var stubbedError: Error?

  override init() {
    super.init(
      siteKey: "test_site_key",
      resourceName: "test_resource_name",
      apiKey: "test_api_key",
      requestHooks: []
    )
  }

  override func getToken(completion handler: @escaping (GACAppCheckToken?, Error?) -> Void) {
    handler(stubbedToken, stubbedError)
  }

  override func getLimitedUseToken(completion handler: @escaping (GACAppCheckToken?, Error?)
    -> Void) {
    handler(stubbedToken, stubbedError)
  }
}

final class FIRRecaptchaEnterpriseProviderTests: XCTestCase {
  var provider: RecaptchaEnterpriseProvider!
  var fakeInternalProvider: FakeGACRecaptchaEnterpriseProvider!

  override func setUp() {
    super.setUp()
    fakeInternalProvider = FakeGACRecaptchaEnterpriseProvider()
    provider = RecaptchaEnterpriseProvider(recaptchaEnterpriseProvider: fakeInternalProvider)
  }

  override func tearDown() {
    provider = nil
    fakeInternalProvider = nil
    super.tearDown()
  }

  func testInitWithValidApp() {
    let options = FirebaseOptions(googleAppID: "app_id", gcmSenderID: "sender_id")
    options.apiKey = "api_key"
    options.projectID = "project_id"
    let app = FirebaseApp(instanceWithName: "testInitWithValidApp", options: options)
    app.isDataCollectionDefaultEnabled = false

    XCTAssertNotNil(RecaptchaEnterpriseProvider(app: app, siteKey: "test_site_key"))
  }

  func testInitWithIncompleteApp() {
    let options = FirebaseOptions(googleAppID: "app_id", gcmSenderID: "sender_id")
    options.projectID = "project_id"
    let missingAPIKeyApp = FirebaseApp(
      instanceWithName: "testInitWithIncompleteApp1",
      options: options
    )
    missingAPIKeyApp.isDataCollectionDefaultEnabled = false

    XCTAssertNil(RecaptchaEnterpriseProvider(app: missingAPIKeyApp, siteKey: "test_site_key"))

    options.projectID = nil
    options.apiKey = "api_key"
    let missingProjectIDApp = FirebaseApp(
      instanceWithName: "testInitWithIncompleteApp2",
      options: options
    )
    missingProjectIDApp.isDataCollectionDefaultEnabled = false
    XCTAssertNil(RecaptchaEnterpriseProvider(app: missingProjectIDApp, siteKey: "test_site_key"))
  }

  func testGetTokenSuccess() {
    let date = Date()
    let validInternalToken = GACAppCheckToken(
      token: "valid_token",
      expirationDate: date,
      receivedAtDate: date
    )
    fakeInternalProvider.stubbedToken = validInternalToken

    let expectation = self.expectation(description: "getToken")

    provider.getToken { token, error in
      XCTAssertEqual(token?.token, validInternalToken.token)
      XCTAssertEqual(token?.expirationDate, validInternalToken.expirationDate)
      XCTAssertEqual(token?.receivedAtDate, validInternalToken.receivedAtDate)
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
    let validInternalToken = GACAppCheckToken(
      token: "TEST_ValidToken",
      expirationDate: date,
      receivedAtDate: date
    )
    fakeInternalProvider.stubbedToken = validInternalToken

    let expectation = self.expectation(description: "getLimitedUseToken")

    provider.getLimitedUseToken { token, error in
      XCTAssertEqual(token?.token, validInternalToken.token)
      XCTAssertEqual(token?.expirationDate, validInternalToken.expirationDate)
      XCTAssertEqual(token?.receivedAtDate, validInternalToken.receivedAtDate)
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
