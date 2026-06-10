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

#if os(iOS) && !targetEnvironment(macCatalyst) || os(visionOS)

  import AppCheckCore
  import FirebaseAppCheck
  import FirebaseCore
  import SharedTestUtilities
  import XCTest

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

  final class RecaptchaProviderTests: XCTestCase {
    var provider: RecaptchaProvider!
    var fakeInternalProvider: FakeInternalProvider!

    override func setUp() {
      super.setUp()
      fakeInternalProvider = FakeInternalProvider()
      provider = RecaptchaProvider.testInstance(recaptchaProvider: fakeInternalProvider)
    }

    override func tearDown() {
      provider = nil
      fakeInternalProvider = nil
      super.tearDown()
    }

    func testInitWithIncompleteApp() {
      let options = FirebaseOptions(googleAppID: "1:123456789:ios:abc123", gcmSenderID: "sender_id")
      options.projectID = "project_id"
      options.recaptchaSiteKey = "test_site_key"

      let appName = "testInitWithIncompleteApp1"
      let missingAPIKeyApp: FirebaseApp
      if let existingApp = FirebaseApp.app(name: appName) {
        missingAPIKeyApp = existingApp
      } else {
        FirebaseApp.configure(name: appName, options: options)
        missingAPIKeyApp = FirebaseApp.app(name: appName)!
      }
      missingAPIKeyApp.isDataCollectionDefaultEnabled = false

      XCTAssertNil(RecaptchaProvider(app: missingAPIKeyApp))

      options.projectID = nil
      options.apiKey = "api_key"
      options.recaptchaSiteKey = "test_site_key"

      let appName2 = "testInitWithIncompleteApp2"
      let missingProjectIDApp: FirebaseApp
      if let existingApp = FirebaseApp.app(name: appName2) {
        missingProjectIDApp = existingApp
      } else {
        FirebaseApp.configure(name: appName2, options: options)
        missingProjectIDApp = FirebaseApp.app(name: appName2)!
      }
      missingProjectIDApp.isDataCollectionDefaultEnabled = false
      XCTAssertNil(RecaptchaProvider(app: missingProjectIDApp))
    }

    func testInitWithMissingSiteKey() {
      let options = FirebaseOptions(googleAppID: "1:123456789:ios:abc123", gcmSenderID: "sender_id")
      options.apiKey = "api_key"
      options.projectID = "project_id"
      // options.recaptchaSiteKey is nil

      let appName = "testInitWithMissingSiteKey"
      let app: FirebaseApp
      if let existingApp = FirebaseApp.app(name: appName) {
        app = existingApp
      } else {
        FirebaseApp.configure(name: appName, options: options)
        app = FirebaseApp.app(name: appName)!
      }
      app.isDataCollectionDefaultEnabled = false

      XCTAssertThrowsError(try ExceptionCatcher.catchException {
        _ = RecaptchaProvider(app: app)
      }) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, NSExceptionName.invalidArgumentException.rawValue)
        XCTAssertEqual(nsError.code, -114)
        XCTAssertTrue((nsError.userInfo["ExceptionReason"] as? String)?
          .contains("recaptchaSiteKey") ?? false)
      }
    }

    func testInitWithMissingSDKThrows() {
      let options = FirebaseOptions(googleAppID: "1:123456789:ios:abc123", gcmSenderID: "sender_id")
      options.apiKey = "api_key"
      options.projectID = "project_id"
      options.recaptchaSiteKey = "test_site_key"

      let appName = "testInitWithMissingSDKThrows"
      let app: FirebaseApp
      if let existingApp = FirebaseApp.app(name: appName) {
        app = existingApp
      } else {
        FirebaseApp.configure(name: appName, options: options)
        app = FirebaseApp.app(name: appName)!
      }
      app.isDataCollectionDefaultEnabled = false

      XCTAssertThrowsError(try ExceptionCatcher.catchException {
        _ = RecaptchaProvider(app: app)
      }) { error in
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, NSExceptionName.internalInconsistencyException.rawValue)
        XCTAssertEqual(nsError.code, -114)
        XCTAssertTrue((nsError.userInfo["ExceptionReason"] as? String)?
          .contains("reCAPTCHA Enterprise SDK is not linked") ?? false)
      }
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

#endif
