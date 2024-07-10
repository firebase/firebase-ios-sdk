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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class VerifyPasswordTests: RPCBaseTests {
  let kTestOOBCode = "OOBCode"
  let kTestEmail = "testEmail."
  let kTestPassword = "testPassword"

  func testVerifyPasswordRequest() async throws {
    let kEmailKey = "email"
    let kPasswordKey = "password"
    let kCaptchaChallengeKey = "captchaChallenge"
    let kCaptchaResponseKey = "captchaResponse"
    let kSecureTokenKey = "returnSecureToken"
    let kExpectedAPIURL =
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=APIKey"
    try await checkRequest(
      request: makeVerifyPasswordRequest(),
      expected: kExpectedAPIURL,
      key: kEmailKey,
      value: kTestEmail
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kPasswordKey], kTestPassword)
    XCTAssertNil(requestDictionary[kCaptchaChallengeKey])
    XCTAssertNil(requestDictionary[kCaptchaResponseKey])
    XCTAssertTrue(try XCTUnwrap(requestDictionary[kSecureTokenKey] as? Bool))
  }

  func testVerifyPasswordRequestOptionalFields() async throws {
    let kEmailKey = "email"
    let kPasswordKey = "password"
    let kCaptchaChallengeKey = "captchaChallenge"
    let kTestCaptchaChallenge = "testCaptchaChallenge"
    let kCaptchaResponseKey = "captchaResponse"
    let kTestCaptchaResponse = "testCaptchaResponse"
    let kSecureTokenKey = "returnSecureToken"
    let kTestPendingToken = "testPendingToken"
    let kClientTypeKey = "clientType"
    let kTestClientType = "testClientType"
    let kRecaptchaVersionKey = "recaptchaVersion"
    let kTestRecaptchaVersion = "testRecaptchaVersion"
    let kExpectedAPIURL =
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=APIKey"
    let request = makeVerifyPasswordRequest()
    request.pendingIDToken = kTestPendingToken
    request.captchaChallenge = kTestCaptchaChallenge
    request.captchaResponse = kTestCaptchaResponse
    request.clientType = kTestClientType
    request.recaptchaVersion = kTestRecaptchaVersion
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kEmailKey,
      value: kTestEmail
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kPasswordKey], kTestPassword)
    XCTAssertEqual(requestDictionary[kCaptchaChallengeKey], kTestCaptchaChallenge)
    XCTAssertEqual(requestDictionary[kCaptchaResponseKey], kTestCaptchaResponse)
    XCTAssertEqual(requestDictionary[kClientTypeKey], kTestClientType)
    XCTAssertEqual(requestDictionary[kRecaptchaVersionKey], kTestRecaptchaVersion)
    XCTAssertTrue(try XCTUnwrap(requestDictionary[kSecureTokenKey] as? Bool))
  }

  func testVerifyPasswordRequestErrors() async throws {
    let kUserDisabledErrorMessage = "USER_DISABLED"
    let kOperationNotAllowedErrorMessage = "OPERATION_NOT_ALLOWED"
    let kEmailNotFoundErrorMessage = "EMAIL_NOT_FOUND"
    let kWrongPasswordErrorMessage = "INVALID_PASSWORD"
    let kInvalidEmailErrorMessage = "INVALID_EMAIL"
    let kBadRequestErrorMessage = "Bad Request"
    let kInvalidKeyReasonValue = "keyInvalid"
    let kAppNotAuthorizedReasonValue = "ipRefererBlocked"
    let kTooManyAttemptsErrorMessage = "TOO_MANY_ATTEMPTS_TRY_LATER:"
    let kPasswordLoginDisabledErrorMessage = "PASSWORD_LOGIN_DISABLED"

    try await checkBackendError(
      request: makeVerifyPasswordRequest(),
      message: kUserDisabledErrorMessage,
      errorCode: AuthErrorCode.userDisabled
    )
    try await checkBackendError(
      request: makeVerifyPasswordRequest(),
      message: kEmailNotFoundErrorMessage,
      errorCode: AuthErrorCode.userNotFound
    )
    try await checkBackendError(
      request: makeVerifyPasswordRequest(),
      message: kWrongPasswordErrorMessage,
      errorCode: AuthErrorCode.wrongPassword
    )
    try await checkBackendError(
      request: makeVerifyPasswordRequest(),
      message: kInvalidEmailErrorMessage,
      errorCode: AuthErrorCode.invalidEmail
    )
    try await checkBackendError(
      request: makeVerifyPasswordRequest(),
      message: kTooManyAttemptsErrorMessage,
      errorCode: AuthErrorCode.tooManyRequests
    )
    try await checkBackendError(
      request: makeVerifyPasswordRequest(),
      message: kBadRequestErrorMessage,
      reason: kInvalidKeyReasonValue,
      errorCode: AuthErrorCode.invalidAPIKey
    )
    try await checkBackendError(
      request: makeVerifyPasswordRequest(),
      message: kOperationNotAllowedErrorMessage,
      errorCode: AuthErrorCode.operationNotAllowed
    )
    try await checkBackendError(
      request: makeVerifyPasswordRequest(),
      message: kPasswordLoginDisabledErrorMessage,
      errorCode: AuthErrorCode.operationNotAllowed
    )
    try await checkBackendError(
      request: makeVerifyPasswordRequest(),
      message: kBadRequestErrorMessage,
      reason: kAppNotAuthorizedReasonValue,
      errorCode: AuthErrorCode.appNotAuthorized
    )
  }

  /** @fn testSuccessfulVerifyPasswordResponse
      @brief Tests a successful attempt of the verify password flow.
   */
  func testSuccessfulVerifyPasswordResponse() async throws {
    let kLocalIDKey = "localId"
    let kTestLocalID = "testLocalId"
    let kEmailKey = "email"
    let kTestEmail = "testgmail.com"
    let kDisplayNameKey = "displayName"
    let kTestDisplayName = "testDisplayName"
    let kIDTokenKey = "idToken"
    let kTestIDToken = "ID_TOKEN"
    let kExpiresInKey = "expiresIn"
    let kTestExpiresIn = "12345"
    let kRefreshTokenKey = "refreshToken"
    let kTestRefreshToken = "REFRESH_TOKEN"
    let kPhotoUrlKey = "photoUrl"
    let kTestPhotoUrl = "www.example.com"

    rpcIssuer?.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: [
        kLocalIDKey: kTestLocalID,
        kEmailKey: kTestEmail,
        kDisplayNameKey: kTestDisplayName,
        kIDTokenKey: kTestIDToken,
        kExpiresInKey: kTestExpiresIn,
        kRefreshTokenKey: kTestRefreshToken,
        kPhotoUrlKey: kTestPhotoUrl,
      ])
    }
    let rpcResponse = try await AuthBackend.call(with: makeVerifyPasswordRequest())
    XCTAssertEqual(rpcResponse.email, kTestEmail)
    XCTAssertEqual(rpcResponse.localID, kTestLocalID)
    XCTAssertEqual(rpcResponse.displayName, kTestDisplayName)
    XCTAssertEqual(rpcResponse.idToken, kTestIDToken)
    let expiresIn = try XCTUnwrap(rpcResponse.approximateExpirationDate?.timeIntervalSinceNow)
    XCTAssertEqual(expiresIn, 12345, accuracy: 0.1)
    XCTAssertEqual(rpcResponse.refreshToken, kTestRefreshToken)
    XCTAssertEqual(rpcResponse.photoURL?.absoluteString, kTestPhotoUrl)
  }

  private func makeVerifyPasswordRequest() -> VerifyPasswordRequest {
    return VerifyPasswordRequest(email: kTestEmail, password: kTestPassword,
                                 requestConfiguration: makeRequestConfiguration())
  }
}
