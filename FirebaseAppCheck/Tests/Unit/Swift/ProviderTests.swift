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
import FirebaseCore
import Foundation
import XCTest

import FirebaseAppCheck
#if SWIFT_PACKAGE
  @testable import FirebaseAppCheckSwift
#else
  @testable import FirebaseAppCheck
#endif // SWIFT_PACKAGE
internal import FirebaseCoreExtension

/// Tests the behavior shared by the providers that wrap an App Check Core provider.
private protocol WrappingProviderTests: XCTestCase {
  var coreProvider: FakeAppCheckCoreProvider! { get }
  var provider: AppCheckProvider! { get }
}

private extension WrappingProviderTests {
  func verifyGetTokenSuccess() {
    let validInternalToken = AppCheckCoreToken(token: "valid_token", expirationDate: Date(),
                                               receivedAt: Date(timeIntervalSince1970: 1000))
    coreProvider.tokenResult = (validInternalToken, nil)

    let handlerCalled = CallRecorder()
    provider.getToken { token, error in
      handlerCalled.called = true
      XCTAssertEqual(token?.token, validInternalToken.token)
      XCTAssertEqual(token?.expirationDate, validInternalToken.expirationDate)
      XCTAssertEqual(token?.receivedAtDate, validInternalToken.receivedAtDate)
      XCTAssertNil(error)
    }

    XCTAssertTrue(handlerCalled.called)
    XCTAssertEqual(coreProvider.getTokenCount, 1)
  }

  func verifyGetTokenAPIError() {
    let expectedError = NSError(domain: "testGetTokenAPIError", code: -1)
    coreProvider.tokenResult = (nil, expectedError)

    let handlerCalled = CallRecorder()
    provider.getToken { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      // Provider errors are not converted to the public error domain.
      XCTAssertTrue(error as NSError? === expectedError)
    }

    XCTAssertTrue(handlerCalled.called)
  }

  func verifyGetLimitedUseTokenSuccess() {
    let validInternalToken = AppCheckCoreToken(token: "TEST_ValidToken", expirationDate: Date(),
                                               receivedAt: Date(timeIntervalSince1970: 1000))
    coreProvider.limitedUseTokenResult = (validInternalToken, nil)

    let handlerCalled = CallRecorder()
    provider.getLimitedUseToken? { token, error in
      handlerCalled.called = true
      XCTAssertEqual(token?.token, validInternalToken.token)
      XCTAssertEqual(token?.expirationDate, validInternalToken.expirationDate)
      XCTAssertEqual(token?.receivedAtDate, validInternalToken.receivedAtDate)
      XCTAssertNil(error)
    }

    XCTAssertTrue(handlerCalled.called)
    XCTAssertEqual(coreProvider.getLimitedUseTokenCount, 1)
    XCTAssertEqual(coreProvider.getTokenCount, 0)
  }

  func verifyGetLimitedUseTokenProviderError() {
    let expectedError = NSError(domain: "TEST_LimitedUseToken_Error", code: -1)
    coreProvider.limitedUseTokenResult = (nil, expectedError)

    let handlerCalled = CallRecorder()
    provider.getLimitedUseToken? { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      XCTAssertTrue(error as NSError? === expectedError)
    }

    XCTAssertTrue(handlerCalled.called)
  }

  func verifyAsyncVariants() async throws {
    coreProvider.tokenResult = (AppCheckCoreToken(token: "token", expirationDate: .distantFuture),
                                nil)
    let token = try await provider.getToken()
    XCTAssertEqual(token.token, "token")
  }
}

// MARK: - DeviceCheckProvider

@available(watchOS 9.0, *)
final class DeviceCheckProviderTests: XCTestCase, WrappingProviderTests {
  fileprivate var coreProvider: FakeAppCheckCoreProvider!
  fileprivate var provider: AppCheckProvider!

  override func setUp() {
    super.setUp()
    coreProvider = FakeAppCheckCoreProvider()
    let provider = DeviceCheckProvider(app: AppCheckTestUtils.app())!
    provider.deviceCheckProvider = coreProvider
    self.provider = provider
  }

  func testInitWithValidApp() throws {
    let provider = try XCTUnwrap(DeviceCheckProvider(app: AppCheckTestUtils.app()))
    XCTAssertTrue(provider.deviceCheckProvider is AppCheckCoreDeviceCheckProvider)
  }

  func testInitWithIncompleteApp() {
    XCTAssertNil(DeviceCheckProvider(app: AppCheckTestUtils.app(apiKey: nil)))
    XCTAssertNil(DeviceCheckProvider(app: AppCheckTestUtils.app(projectID: nil)))
  }

  func testGetTokenSuccess() { verifyGetTokenSuccess() }
  func testGetTokenAPIError() { verifyGetTokenAPIError() }
  func testGetLimitedUseTokenSuccess() { verifyGetLimitedUseTokenSuccess() }
  func testGetLimitedUseTokenProviderError() { verifyGetLimitedUseTokenProviderError() }
  func testAsyncVariants() async throws { try await verifyAsyncVariants() }

  func testAsyncLimitedUseToken() async throws {
    coreProvider.limitedUseTokenResult = (AppCheckCoreToken(token: "limited",
                                                            expirationDate: .distantFuture), nil)
    let provider = try XCTUnwrap(provider as? DeviceCheckProvider)
    let token = try await provider.getLimitedUseToken()
    XCTAssertEqual(token.token, "limited")
  }

  // `DeviceCheckProviderFactory` is tested in `AppCheckPublicBehaviorTests`.
}

// MARK: - AppAttestProvider

@available(macOS 11.3, watchOS 9.0, *)
final class AppAttestProviderTests: XCTestCase, WrappingProviderTests {
  fileprivate var coreProvider: FakeAppCheckCoreProvider!
  fileprivate var provider: AppCheckProvider!

  override func setUp() {
    super.setUp()
    coreProvider = FakeAppCheckCoreProvider()
    let provider = AppAttestProvider(app: AppCheckTestUtils.app())!
    provider.appAttestProvider = coreProvider
    self.provider = provider
  }

  func testInitWithValidApp() throws {
    let provider = try XCTUnwrap(AppAttestProvider(app: AppCheckTestUtils.app()))
    XCTAssertTrue(provider.appAttestProvider is AppCheckCoreAppAttestProvider)
  }

  func testInitWithIncompleteAppSucceeds() {
    // Like the Objective-C implementation, the App Attest provider doesn't validate options.
    XCTAssertNotNil(AppAttestProvider(app: AppCheckTestUtils.app(apiKey: nil)))
  }

  func testGetTokenSuccess() { verifyGetTokenSuccess() }
  func testGetTokenAPIError() { verifyGetTokenAPIError() }
  func testGetLimitedUseTokenSuccess() { verifyGetLimitedUseTokenSuccess() }
  func testGetLimitedUseTokenProviderError() { verifyGetLimitedUseTokenProviderError() }
  func testAsyncVariants() async throws { try await verifyAsyncVariants() }

  func testAsyncLimitedUseToken() async throws {
    coreProvider.limitedUseTokenResult = (AppCheckCoreToken(token: "limited",
                                                            expirationDate: .distantFuture), nil)
    let provider = try XCTUnwrap(provider as? AppAttestProvider)
    let token = try await provider.getLimitedUseToken()
    XCTAssertEqual(token.token, "limited")
  }
}
