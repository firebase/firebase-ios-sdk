// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
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
class SetAccountInfoTests: RPCBaseTests {
  func testSetAccountInfoRequest() throws {
    let kExpectedAPIURL =
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/setAccountInfo?key=APIKey"

    let request = setAccountInfoRequest()
    request.returnSecureToken = false

    let rpcIssuer = try checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: "should_be_empty_dictionary",
      value: nil
    )
    let decodedRequest = try XCTUnwrap(rpcIssuer.decodedRequest)
    XCTAssertEqual(decodedRequest.count, 0)
  }

  func testSetAccountInfoRequestOptionalFields() throws {
    let kIDTokenKey = "idToken"
    let kDisplayNameKey = "displayName"
    let kTestDisplayName = "testDisplayName"
    let kLocalIDKey = "localId"
    let kTestLocalID = "testLocalId"
    let kEmailKey = "email"
    let ktestEmail = "testEmail"
    let kPasswordKey = "password"
    let kTestPassword = "testPassword"
    let kPhotoURLKey = "photoUrl"
    let kTestPhotoURL = "testPhotoUrl"
    let kProvidersKey = "provider"
    let kTestProviders = "testProvider"
    let kOOBCodeKey = "oobCode"
    let kTestOOBCode = "testOobCode"
    let kEmailVerifiedKey = "emailVerified"
    let kUpgradeToFederatedLoginKey = "upgradeToFederatedLogin"
    let kCaptchaChallengeKey = "captchaChallenge"
    let kTestCaptchaChallenge = "TestCaptchaChallenge"
    let kCaptchaResponseKey = "captchaResponse"
    let kTestCaptchaResponse = "TestCaptchaResponse"
    let kDeleteAttributesKey = "deleteAttribute"
    let kTestDeleteAttributes = "TestDeleteAttributes"
    let kDeleteProvidersKey = "deleteProvider"
    let kTestDeleteProviders = "TestDeleteProviders"
    let kReturnSecureTokenKey = "returnSecureToken"
    let kTestAccessToken = "accessToken"
    let kExpectedAPIURL =
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/setAccountInfo?key=APIKey"

    let request = setAccountInfoRequest()
    request.accessToken = kTestAccessToken
    request.displayName = kTestDisplayName
    request.localID = kTestLocalID
    request.email = ktestEmail
    request.password = kTestPassword
    request.providers = [kTestProviders]
    request.oobCode = kTestOOBCode
    request.emailVerified = true
    request.photoURL = URL(string: kTestPhotoURL)
    request.upgradeToFederatedLogin = true
    request.captchaChallenge = kTestCaptchaChallenge
    request.captchaResponse = kTestCaptchaResponse
    request.deleteAttributes = [kTestDeleteAttributes]
    request.deleteProviders = [kTestDeleteProviders]

    let rpcIssuer = try checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kIDTokenKey,
      value: kTestAccessToken
    )
    let decodedRequest = try XCTUnwrap(rpcIssuer.decodedRequest)
    XCTAssertEqual(decodedRequest[kIDTokenKey] as? String, kTestAccessToken)
    XCTAssertEqual(decodedRequest[kDisplayNameKey] as? String, kTestDisplayName)
    XCTAssertEqual(decodedRequest[kLocalIDKey] as? String, kTestLocalID)
    XCTAssertEqual(decodedRequest[kEmailKey] as? String, ktestEmail)
    XCTAssertEqual(decodedRequest[kPasswordKey] as? String, kTestPassword)
    XCTAssertEqual(decodedRequest[kPhotoURLKey] as? String, kTestPhotoURL)
    XCTAssertEqual(decodedRequest[kProvidersKey] as? [String], [kTestProviders])
    XCTAssertEqual(decodedRequest[kOOBCodeKey] as? String, kTestOOBCode)
    XCTAssertEqual(decodedRequest[kEmailVerifiedKey] as? Bool, true)
    XCTAssertEqual(decodedRequest[kUpgradeToFederatedLoginKey] as? Bool, true)
    XCTAssertEqual(decodedRequest[kCaptchaChallengeKey] as? String, kTestCaptchaChallenge)
    XCTAssertEqual(decodedRequest[kCaptchaResponseKey] as? String, kTestCaptchaResponse)
    XCTAssertEqual(decodedRequest[kDeleteAttributesKey] as? [String], [kTestDeleteAttributes])
    XCTAssertEqual(decodedRequest[kDeleteProvidersKey] as? [String], [kTestDeleteProviders])
    XCTAssertEqual(decodedRequest[kReturnSecureTokenKey] as? Bool, true)
  }

  func testSetAccountInfoErrors() throws {
    let kEmailExistsErrorMessage = "EMAIL_EXISTS"
    let kEmailSignUpNotAllowedErrorMessage = "OPERATION_NOT_ALLOWED"
    let kPasswordLoginDisabledErrorMessage = "PASSWORD_LOGIN_DISABLED"
    let kCredentialTooOldErrorMessage = "CREDENTIAL_TOO_OLD_LOGIN_AGAIN"
    let kInvalidUserTokenErrorMessage = "INVALID_ID_TOKEN"
    let kUserDisabledErrorMessage = "USER_DISABLED"
    let kInvalidEmailErrorMessage = "INVALID_EMAIL"
    let kExpiredActionCodeErrorMessage = "EXPIRED_OOB_CODE:"
    let kInvalidActionCodeErrorMessage = "INVALID_OOB_CODE"
    let kInvalidMessagePayloadErrorMessage = "INVALID_MESSAGE_PAYLOAD"
    let kInvalidSenderErrorMessage = "INVALID_SENDER"
    let kInvalidRecipientEmailErrorMessage = "INVALID_RECIPIENT_EMAIL"
    let kWeakPasswordErrorMessage = "WEAK_PASSWORD : Password should be at least 6 characters"
    let kWeakPasswordClientErrorMessage = "Password should be at least 6 characters"

    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kEmailExistsErrorMessage,
      errorCode: AuthErrorCode.emailAlreadyInUse
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kEmailSignUpNotAllowedErrorMessage,
      errorCode: AuthErrorCode.operationNotAllowed
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kPasswordLoginDisabledErrorMessage,
      errorCode: AuthErrorCode.operationNotAllowed
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kUserDisabledErrorMessage,
      errorCode: AuthErrorCode.userDisabled
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kInvalidUserTokenErrorMessage,
      errorCode: AuthErrorCode.invalidUserToken
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kCredentialTooOldErrorMessage,
      errorCode: AuthErrorCode.requiresRecentLogin
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kWeakPasswordErrorMessage,
      errorCode: AuthErrorCode.weakPassword,
      errorReason: kWeakPasswordClientErrorMessage
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kInvalidEmailErrorMessage,
      errorCode: AuthErrorCode.invalidEmail
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kInvalidActionCodeErrorMessage,
      errorCode: AuthErrorCode.invalidActionCode
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kExpiredActionCodeErrorMessage,
      errorCode: AuthErrorCode.expiredActionCode
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kInvalidMessagePayloadErrorMessage,
      errorCode: AuthErrorCode.invalidMessagePayload
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kInvalidSenderErrorMessage,
      errorCode: AuthErrorCode.invalidSender
    )
    try checkBackendError(
      request: setAccountInfoRequest(),
      message: kInvalidRecipientEmailErrorMessage,
      errorCode: AuthErrorCode.invalidRecipientEmail
    )
  }

  /** @fn testSuccessfulSetAccountInfoResponse
      @brief This test simulates a successful @c SetAccountInfo flow.
   */
  func testSuccessfulSetAccountInfoResponse() throws {
    let kIDTokenKey = "idToken"
    let kPhotoUrlKey = "photoUrl"
    let kTestPhotoURL = "testPhotoUrl"
    let kProviderUserInfoKey = "providerUserInfo"
    let kTestExpiresIn = "12345"
    let kTestIDToken = "ID_TOKEN"
    let kExpiresInKey = "expiresIn"
    let kRefreshTokenKey = "refreshToken"
    let kTestRefreshToken = "REFRESH_TOKEN"

    var callbackInvoked = false
    var rpcResponse: SetAccountInfoResponse?
    var rpcError: NSError?

    AuthBackend.post(with: setAccountInfoRequest()) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }

    _ = try rpcIssuer?.respond(withJSON: [kProviderUserInfoKey: [[kPhotoUrlKey: kTestPhotoURL]],
                                          kIDTokenKey: kTestIDToken,
                                          kExpiresInKey: kTestExpiresIn,
                                          kRefreshTokenKey: kTestRefreshToken])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    let response = try XCTUnwrap(rpcResponse)
    XCTAssertEqual(response.providerUserInfo?.first?.photoURL?.absoluteString, kTestPhotoURL)
    XCTAssertEqual(response.idToken, kTestIDToken)
    XCTAssertEqual(response.refreshToken, kTestRefreshToken)
    let expiresIn = try XCTUnwrap(response.approximateExpirationDate?.timeIntervalSinceNow)
    XCTAssertEqual(expiresIn, 12345, accuracy: 0.1)
  }

  private func setAccountInfoRequest() -> SetAccountInfoRequest {
    return SetAccountInfoRequest(requestConfiguration: makeRequestConfiguration())
  }
}
