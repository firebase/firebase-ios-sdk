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
class SignUpNewUserTests: RPCBaseTests {
  private let kEmailKey = "email"
  private let kTestEmail = "testgmail.com"
  private let kDisplayNameKey = "displayName"
  private let kTestDisplayName = "DisplayName"
  private let kPasswordKey = "password"
  private let kTestPassword = "Password"
  private let kReturnSecureTokenKey = "returnSecureToken"
  private let kExpectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=APIKey"

  /** @fn testSignUpNewUserRequestAnonymous
      @brief Tests the encoding of a sign up new user request when user is signed in anonymously.
   */
  func testSignUpNewUserRequestAnonymous() async throws {
    let request = makeSignUpNewUserRequestAnonymous()
    request.returnSecureToken = false
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kEmailKey,
      value: nil
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertNil(requestDictionary[kDisplayNameKey])
    XCTAssertNil(requestDictionary[kPasswordKey])
    XCTAssertNil(requestDictionary[kReturnSecureTokenKey])
  }

  /** @fn testSignUpNewUserRequestNotAnonymous
      @brief Tests the encoding of a sign up new user request when user is not signed in anonymously.
   */
  func testSignUpNewUserRequestNotAnonymous() async throws {
    let request = makeSignUpNewUserRequest()
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kEmailKey,
      value: kTestEmail
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kDisplayNameKey], kTestDisplayName)
    XCTAssertEqual(requestDictionary[kPasswordKey], kTestPassword)
    XCTAssertTrue(try XCTUnwrap(requestDictionary[kReturnSecureTokenKey] as? Bool))
  }

  /** @fn testSuccessfulSignUp
      @brief This test simulates a complete sign up flow with no errors.
   */
  func testSuccessfulSignUp() async throws {
    let kIDTokenKey = "idToken"
    let kTestIDToken = "ID_TOKEN"
    let kTestExpiresIn = "12345"
    let kTestRefreshToken = "REFRESH_TOKEN"
    let kExpiresInKey = "expiresIn"
    let kRefreshTokenKey = "refreshToken"

    rpcIssuer?.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: [
        kIDTokenKey: kTestIDToken,
        kExpiresInKey: kTestExpiresIn,
        kRefreshTokenKey: kTestRefreshToken,
      ])
    }
    let rpcResponse = try await AuthBackend.call(with: makeSignUpNewUserRequest())
    XCTAssertEqual(rpcResponse.refreshToken, kTestRefreshToken)
    let expiresIn = try XCTUnwrap(rpcResponse.approximateExpirationDate?.timeIntervalSinceNow)
    XCTAssertEqual(expiresIn, 12345, accuracy: 0.1)
  }

  func testSignUpNewUserRequestErrors() async throws {
    let kEmailAlreadyInUseErrorMessage = "EMAIL_EXISTS"
    let kEmailSignUpNotAllowedErrorMessage = "OPERATION_NOT_ALLOWED"
    let kPasswordLoginDisabledErrorMessage = "PASSWORD_LOGIN_DISABLED:"
    let kInvalidEmailErrorMessage = "INVALID_EMAIL"
    let kWeakPasswordErrorMessage = "WEAK_PASSWORD : Password should be at least 6 characters"
    let kWeakPasswordClientErrorMessage = "Password should be at least 6 characters"

    try await checkBackendError(
      request: makeSignUpNewUserRequest(),
      message: kEmailAlreadyInUseErrorMessage,
      errorCode: AuthErrorCode.emailAlreadyInUse
    )
    try await checkBackendError(
      request: makeSignUpNewUserRequest(),
      message: kEmailSignUpNotAllowedErrorMessage,
      errorCode: AuthErrorCode.operationNotAllowed
    )
    try await checkBackendError(
      request: makeSignUpNewUserRequest(),
      message: kPasswordLoginDisabledErrorMessage,
      errorCode: AuthErrorCode.operationNotAllowed
    )
    try await checkBackendError(
      request: makeSignUpNewUserRequest(),
      message: kInvalidEmailErrorMessage,
      errorCode: AuthErrorCode.invalidEmail
    )
    try await checkBackendError(
      request: makeSignUpNewUserRequest(),
      message: kWeakPasswordErrorMessage,
      errorCode: AuthErrorCode.weakPassword,
      errorReason: kWeakPasswordClientErrorMessage
    )
  }

  /** @fn testSignUpNewUserRequestOptionalFields
      @brief Tests the encoding of a sign up new user request with optional fields.
   */
  func testSignUpNewUserRequestOptionalFields() async throws {
    let kEmailKey = "email"
    let kPasswordKey = "password"
    let kCaptchaResponseKey = "captchaResponse"
    let kTestCaptchaResponse = "testCaptchaResponse"
    let kClientTypeKey = "clientType"
    let kTestClientType = "testClientType"
    let kRecaptchaVersionKey = "recaptchaVersion"
    let kTestRecaptchaVersion = "testRecaptchaVersion"
    let request = makeSignUpNewUserRequest()
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
    XCTAssertEqual(requestDictionary[kDisplayNameKey], kTestDisplayName)
    XCTAssertEqual(requestDictionary[kPasswordKey], kTestPassword)
    XCTAssertTrue(try XCTUnwrap(requestDictionary[kReturnSecureTokenKey] as? Bool))
    XCTAssertEqual(requestDictionary[kCaptchaResponseKey], kTestCaptchaResponse)
    XCTAssertEqual(requestDictionary[kClientTypeKey], kTestClientType)
    XCTAssertEqual(requestDictionary[kRecaptchaVersionKey], kTestRecaptchaVersion)
  }

  private func makeSignUpNewUserRequestAnonymous() -> SignUpNewUserRequest {
    return SignUpNewUserRequest(requestConfiguration: makeRequestConfiguration())
  }

  private func makeSignUpNewUserRequest() -> SignUpNewUserRequest {
    return SignUpNewUserRequest(email: kTestEmail,
                                password: kTestPassword,
                                displayName: kTestDisplayName,
                                idToken: nil,
                                requestConfiguration: makeRequestConfiguration())
  }
}
