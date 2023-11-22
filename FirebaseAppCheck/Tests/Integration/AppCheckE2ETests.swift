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

import FirebaseAppCheck
import FirebaseCore
import XCTest

final class AppCheckE2ETests: XCTestCase {
  let appName = "test_app_name"
  var app: FirebaseApp!

  override func setUp() {
    AppCheck.setAppCheckProviderFactory(TestAppCheckProviderFactory())
    let options = FirebaseOptions(
      googleAppID: "1:123456789:ios:abc123",
      gcmSenderID: "123456789"
    )
    options.projectID = "test_project_id"
    options.apiKey = "test_api_key"
    FirebaseApp.configure(name: appName, options: options)

    app = FirebaseApp.app(name: appName)
  }

  override func tearDown() {
    let semaphore = DispatchSemaphore(value: 0)
    app.delete { _ in
      semaphore.signal()
    }
    semaphore.wait()
  }

  func testInitAppCheck() throws {
    let appCheck = AppCheck.appCheck(app: app)

    XCTAssertNotNil(appCheck)
  }

  func testInitAppCheckDebugProvider() throws {
    let debugProvider = AppCheckDebugProvider(app: app)

    XCTAssertNotNil(debugProvider)
  }

  func testInitAppCheckDebugProviderFactory() throws {
    let debugProvider = AppCheckDebugProviderFactory().createProvider(with: app)

    XCTAssertNotNil(debugProvider)
  }

  @available(iOS 11.0, macOS 10.15, macCatalyst 13.0, tvOS 11.0, watchOS 9.0, *)
  func testInitDeviceCheckProvider() throws {
    let deviceCheckProvider = DeviceCheckProvider(app: app)

    XCTAssertNotNil(deviceCheckProvider)
  }

  @available(iOS 11.0, macOS 10.15, macCatalyst 13.0, tvOS 11.0, watchOS 9.0, *)
  func testDeviceCheckProviderFactoryCreate() throws {
    let deviceCheckProvider = DeviceCheckProviderFactory().createProvider(with: app)

    XCTAssertNotNil(deviceCheckProvider)
  }

  @available(iOS 14.0, macOS 11.3, macCatalyst 14.5, tvOS 15.0, watchOS 9.0, *)
  func testInitAppAttestProvider() throws {
    let appAttestProvider = AppAttestProvider(app: app)

    XCTAssertNotNil(appAttestProvider)
  }

  // The following test is disabled on macOS since `token(forcingRefresh:handler:)` requires a
  // provisioning profile to access the keychain to cache tokens.
  // See go/firebase-macos-keychain-popups for more details.
  #if !os(macOS) && !targetEnvironment(macCatalyst)
    func testGetToken() throws {
      guard let appCheck = AppCheck.appCheck(app: app) else {
        XCTFail("AppCheck instance is nil.")
        return
      }

      let expectation = XCTestExpectation()
      appCheck.token(forcingRefresh: true) { token, error in
        XCTAssertNil(error)
        XCTAssertNotNil(token)
        XCTAssertEqual(token?.token, TestAppCheckProvider.tokenValue)
        expectation.fulfill()
      }

      wait(for: [expectation], timeout: 0.5)
    }
  #endif // !os(macOS) && !targetEnvironment(macCatalyst)

  func testGetLimitedUseToken() throws {
    guard let appCheck = AppCheck.appCheck(app: app) else {
      XCTFail("AppCheck instance is nil.")
      return
    }

    let expectation = XCTestExpectation()
    appCheck.limitedUseToken { token, error in
      XCTAssertNil(error)
      XCTAssertNotNil(token)
      XCTAssertEqual(token!.token, TestAppCheckProvider.limitedUseTokenValue)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 0.5)
  }
}

class TestAppCheckProvider: NSObject, AppCheckProvider {
  static let tokenValue = "TestToken"
  static let limitedUseTokenValue = "TestLimitedUseToken"

  func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    let token = AppCheckToken(
      token: TestAppCheckProvider.tokenValue,
      expirationDate: Date.distantFuture
    )
    handler(token, nil)
  }

  func getLimitedUseToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    let token = AppCheckToken(
      token: TestAppCheckProvider.limitedUseTokenValue,
      expirationDate: Date.distantFuture
    )
    handler(token, nil)
  }
}

class TestAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    return TestAppCheckProvider()
  }
}
