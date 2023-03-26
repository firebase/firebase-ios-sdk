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

import Foundation
import XCTest

@testable import FirebaseAuth

class RPCBaseTests: XCTestCase {
  let kEmail = "user@company.com"
  let kFakePassword = "!@#$%^"
  let kDisplayName = "Google Doe"
  let kLocalID = "testLocalId"
  let kFakeOobCode = "fakeOobCode"
  let kRefreshToken = "fakeRefreshToken"
  let kCustomToken = "CUSTOM_TOKEN"
  let kFakeEmailSignInLink = "https://test.app.goo.gl/?link=https://test.firebase" +
    "app.com/__/auth/action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueU" +
    "rl%3Dhttps://test.apps.com&ibi=com.test.com&ifl=https://test.firebaseapp.com/__/auth/" +
    "action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueUrl%3Dhttps://" +
    "test.apps.com"
  let kFakeEmailSignInDeeplink =
    "https://example.domain.com/?apiKey=testAPIKey&oobCode=testoobcode&mode=signIn"
  let kContinueURL = "continueURL"
  let kIosBundleID = "testBundleID"
  let kAndroidPackageName = "adroidpackagename"
  let kAndroidMinimumVersion = "3.0"
  let kDynamicLinkDomain = "test.page.link"
  let kTestPhotoURL = "https://host.domain/image"
  let kCreationDateTimeIntervalInSeconds = 1_505_858_500.0
  let kLastSignInDateTimeIntervalInSeconds = 1_505_858_583.0

  /** @var kTestAPIKey
      @brief Fake API key used for testing.
   */
  let kTestAPIKey = "APIKey"

  /** @var kTestFirebaseAppID
      @brief Fake Firebase app ID used for testing.
   */
  let kTestFirebaseAppID = "appID"

  /** @var kTestIdentifier
      @brief Fake identifier key used for testing.
   */
  let kTestIdentifier = "Identifier"

  var rpcIssuer: FakeBackendRPCIssuer?
  var rpcImplementation: AuthBackendImplementation?

  override func setUp() {
    rpcIssuer = FakeBackendRPCIssuer()
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: rpcIssuer)
    rpcImplementation = AuthBackend.implementation()
  }

  override func tearDown() {
    rpcIssuer = nil
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: nil)
  }

  /** @fn checkRequest
      @brief Tests the encoding of a request.
   */
  @discardableResult func checkRequest(request: AuthRPCRequest,
                                       expected: String,
                                       key: String,
                                       value: String?,
                                       checkPostBody: Bool = false) throws -> FakeBackendRPCIssuer {
    AuthBackend.post(withRequest: request) { response, error in
      XCTFail("No explicit response from the fake backend.")
    }
    let rpcIssuer = try XCTUnwrap(rpcIssuer)
    XCTAssertEqual(rpcIssuer.requestURL?.absoluteString, expected)
    if checkPostBody,
       let containsPostBody = request.containsPostBody?() {
      XCTAssertFalse(containsPostBody)
    } else if let requestDictionary = rpcIssuer.decodedRequest as? [String: AnyHashable] {
      XCTAssertEqual(requestDictionary[key], value)
    } else {
      XCTFail("decodedRequest is not a dictionary")
    }
    return rpcIssuer
  }

  /** @fn checkBackendError
      @brief This test checks error messagess from the backend map to the expected error codes
   */
  func checkBackendError(request: AuthRPCRequest,
                         message: String = "",
                         reason: String? = nil,
                         json: [String: AnyHashable]? = nil,
                         errorCode: AuthErrorCode,
                         errorReason: String? = nil,
                         underlyingErrorKey: String? = nil,
                         checkLocalizedDescription: String? = nil) throws {
    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? CreateAuthURIResponse
      rpcError = error as? NSError
    }

    if let json = json {
      _ = try rpcIssuer?.respond(withJSON: json)
    } else if let reason = reason {
      _ = try rpcIssuer?.respond(underlyingErrorMessage: reason, message: message)
    } else {
      _ = try rpcIssuer?.respond(serverErrorMessage: message)
    }

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.code, errorCode.rawValue)
    if errorCode == .internalError {
      let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertNotNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
    }
    if let errorReason {
      XCTAssertEqual(errorReason, rpcError?.userInfo[NSLocalizedFailureReasonErrorKey] as? String)
    }
    if let checkLocalizedDescription {
      let localizedDescription = try XCTUnwrap(rpcError?
        .userInfo[NSLocalizedDescriptionKey] as? String)
      XCTAssertEqual(checkLocalizedDescription, localizedDescription)
    }
  }

  func makeRequestConfiguration() -> AuthRequestConfiguration {
    return AuthRequestConfiguration(
      apiKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
  }

  func setFakeSecureTokenService() {
    rpcIssuer?.fakeSecureTokenServiceJSON = ["access_token": AuthTests.kAccessToken]
  }

  func setFakeGetAccountProvider(withNewDisplayName displayName: String = "Google Doe") {
    let kProviderUserInfoKey = "providerUserInfo"
    let kPhotoUrlKey = "photoUrl"
    let kProviderIDkey = "providerId"
    let kDisplayNameKey = "displayName"
    let kFederatedIDKey = "federatedId"
    let kTestFederatedID = "testFederatedId"
    let kEmailKey = "email"
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = "testPasswordHash"
    let kTestProviderID = "testProviderID"
    let kEmailVerifiedKey = "emailVerified"
    let kLocalIDKey = "localId"

    rpcIssuer?.fakeGetAccountProviderJSON = [[
      kProviderUserInfoKey: [[
        kProviderIDkey: kTestProviderID,
        kDisplayNameKey: kDisplayName,
        kPhotoUrlKey: kTestPhotoURL,
        kFederatedIDKey: kTestFederatedID,
        kEmailKey: kEmail,
      ]],
      kLocalIDKey: kLocalID,
      kDisplayNameKey: displayName,
      kEmailKey: kEmail,
      kPhotoUrlKey: kTestPhotoURL,
      kEmailVerifiedKey: true,
      kPasswordHashKey: kTestPasswordHash,
    ]]
  }

  func setFakeGetAccountProviderAnonymous() {
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = "testPasswordHash"
    let kLocalIDKey = "localId"

    rpcIssuer?.fakeGetAccountProviderJSON = [[
      kLocalIDKey: kLocalID,
      kPasswordHashKey: kTestPasswordHash,
    ]]
  }

  func createGroup() -> DispatchGroup {
    let group = DispatchGroup()
    rpcIssuer?.group = group
    group.enter()
    return group
  }

  func fakeActionCodeSettings() -> ActionCodeSettings {
    let settings = ActionCodeSettings()
    settings.iOSBundleID = kIosBundleID
    settings.setAndroidPackageName(kAndroidPackageName,
                                   installIfNotAvailable: true,
                                   minimumVersion: kAndroidMinimumVersion)
    settings.handleCodeInApp = true
    settings.url = URL(string: kContinueURL)
    settings.dynamicLinkDomain = kDynamicLinkDomain
    return settings
  }
}
