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
class GetOOBConfirmationCodeTests: RPCBaseTests {
  private let kRequestTypeKey = "requestType"
  private let kPasswordResetRequestTypeValue = "PASSWORD_RESET"
  private let kVerifyEmailRequestTypeValue = "VERIFY_EMAIL"
  private let kEmailLinkSignInTypeValue = "EMAIL_SIGNIN"
  private let kEmailKey = "email"
  private let kTestEmail = "testgmail.com"
  private let kAccessTokenKey = "idToken"
  private let kTestAccessToken = "ACCESS_TOKEN"
  private let kContinueURLKey = "continueUrl"
  private let kIosBundleIDKey = "iOSBundleId"
  private let kAndroidPackageNameKey = "androidPackageName"
  private let kAndroidInstallAppKey = "androidInstallApp"
  private let kAndroidMinimumVersionKey = "androidMinimumVersion"
  private let kCanHandleCodeInAppKey = "canHandleCodeInApp"
  private let kDynamicLinkDomainKey = "dynamicLinkDomain"
  private let kExpectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/getOobConfirmationCode?key=APIKey"
  private let kOOBCodeKey = "oobCode"
  private let kTestOOBCode = "OOBCode"

  func testOobRequests() async throws {
    for (request, requestType) in [
      (getPasswordResetRequest, kPasswordResetRequestTypeValue),
      (getSignInWithEmailRequest, kEmailLinkSignInTypeValue),
      (getEmailVerificationRequest, kVerifyEmailRequestTypeValue),
    ] {
      let request = try request()
      try await checkRequest(
        request: request,
        expected: kExpectedAPIURL,
        key: "should_be_empty_dictionary",
        value: nil
      )
      let decodedRequest = try XCTUnwrap(rpcIssuer.decodedRequest)
      XCTAssertEqual(decodedRequest[kRequestTypeKey] as? String, requestType)
      if requestType == kVerifyEmailRequestTypeValue {
        XCTAssertEqual(decodedRequest[kAccessTokenKey] as? String, kTestAccessToken)
      } else {
        XCTAssertEqual(decodedRequest[kEmailKey] as? String, kTestEmail)
      }
      XCTAssertEqual(decodedRequest[kContinueURLKey] as? String, kContinueURL)
      XCTAssertEqual(decodedRequest[kIosBundleIDKey] as? String, kIosBundleID)
      XCTAssertEqual(decodedRequest[kAndroidPackageNameKey] as? String, kAndroidPackageName)
      XCTAssertEqual(decodedRequest[kAndroidMinimumVersionKey] as? String, kAndroidMinimumVersion)
      XCTAssertEqual(decodedRequest[kAndroidInstallAppKey] as? Bool, true)
      XCTAssertEqual(decodedRequest[kCanHandleCodeInAppKey] as? Bool, true)
      XCTAssertEqual(decodedRequest[kDynamicLinkDomainKey] as? String, kDynamicLinkDomain)
    }
  }

  /** @fn testPasswordResetRequestOptionalFields
      @brief Tests the encoding of a password reset request with optional fields.
   */
  func testPasswordResetRequestOptionalFields() async throws {
    let kCaptchaResponseKey = "captchaResp"
    let kTestCaptchaResponse = "testCaptchaResponse"
    let kClientTypeKey = "clientType"
    let kTestClientType = "testClientType"
    let kRecaptchaVersionKey = "recaptchaVersion"
    let kTestRecaptchaVersion = "testRecaptchaVersion"

    for (request, requestType) in [
      (getPasswordResetRequest, kPasswordResetRequestTypeValue),
      (getSignInWithEmailRequest, kEmailLinkSignInTypeValue),
      (getEmailVerificationRequest, kVerifyEmailRequestTypeValue),
    ] {
      let request = try request()
      request.captchaResponse = kTestCaptchaResponse
      request.clientType = kTestClientType
      request.recaptchaVersion = kTestRecaptchaVersion

      try await checkRequest(
        request: request,
        expected: kExpectedAPIURL,
        key: "should_be_empty_dictionary",
        value: nil
      )
      let decodedRequest = try XCTUnwrap(rpcIssuer.decodedRequest)
      XCTAssertEqual(decodedRequest[kRequestTypeKey] as? String, requestType)
      if requestType == kVerifyEmailRequestTypeValue {
        XCTAssertEqual(decodedRequest[kAccessTokenKey] as? String, kTestAccessToken)
      } else {
        XCTAssertEqual(decodedRequest[kEmailKey] as? String, kTestEmail)
      }
      XCTAssertEqual(decodedRequest[kContinueURLKey] as? String, kContinueURL)
      XCTAssertEqual(decodedRequest[kIosBundleIDKey] as? String, kIosBundleID)
      XCTAssertEqual(decodedRequest[kAndroidPackageNameKey] as? String, kAndroidPackageName)
      XCTAssertEqual(decodedRequest[kAndroidMinimumVersionKey] as? String, kAndroidMinimumVersion)
      XCTAssertEqual(decodedRequest[kAndroidInstallAppKey] as? Bool, true)
      XCTAssertEqual(decodedRequest[kCanHandleCodeInAppKey] as? Bool, true)
      XCTAssertEqual(decodedRequest[kDynamicLinkDomainKey] as? String, kDynamicLinkDomain)
      XCTAssertEqual(decodedRequest[kCaptchaResponseKey] as? String, kTestCaptchaResponse)
      XCTAssertEqual(decodedRequest[kClientTypeKey] as? String, kTestClientType)
      XCTAssertEqual(decodedRequest[kRecaptchaVersionKey] as? String, kTestRecaptchaVersion)
    }
  }

  func testGetOOBConfirmationCodeErrors() async throws {
    let kEmailNotFoundMessage = "EMAIL_NOT_FOUND: fake custom message"
    let kMissingEmailErrorMessage = "MISSING_EMAIL"
    let kInvalidEmailErrorMessage = "INVALID_EMAIL:"
    let kInvalidMessagePayloadErrorMessage = "INVALID_MESSAGE_PAYLOAD"
    let kInvalidSenderErrorMessage = "INVALID_SENDER"
    let kMissingIosBundleIDErrorMessage = "MISSING_IOS_BUNDLE_ID"
    let kMissingAndroidPackageNameErrorMessage = "MISSING_ANDROID_PACKAGE_NAME"
    let kUnauthorizedDomainErrorMessage = "UNAUTHORIZED_DOMAIN"
    let kInvalidRecipientEmailErrorMessage = "INVALID_RECIPIENT_EMAIL"
    let kInvalidContinueURIErrorMessage = "INVALID_CONTINUE_URI"
    let kMissingContinueURIErrorMessage = "MISSING_CONTINUE_URI"

    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kEmailNotFoundMessage,
      errorCode: AuthErrorCode.userNotFound
    )
    try await checkBackendError(
      request: getEmailVerificationRequest(),
      message: kMissingEmailErrorMessage,
      errorCode: AuthErrorCode.missingEmail
    )
    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kInvalidEmailErrorMessage,
      errorCode: AuthErrorCode.invalidEmail
    )
    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kInvalidMessagePayloadErrorMessage,
      errorCode: AuthErrorCode.invalidMessagePayload
    )
    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kInvalidSenderErrorMessage,
      errorCode: AuthErrorCode.invalidSender
    )
    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kMissingIosBundleIDErrorMessage,
      errorCode: AuthErrorCode.missingIosBundleID
    )
    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kMissingAndroidPackageNameErrorMessage,
      errorCode: AuthErrorCode.missingAndroidPackageName
    )
    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kUnauthorizedDomainErrorMessage,
      errorCode: AuthErrorCode.unauthorizedDomain
    )
    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kInvalidRecipientEmailErrorMessage,
      errorCode: AuthErrorCode.invalidRecipientEmail
    )
    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kInvalidContinueURIErrorMessage,
      errorCode: AuthErrorCode.invalidContinueURI
    )
    try await checkBackendError(
      request: getPasswordResetRequest(),
      message: kMissingContinueURIErrorMessage,
      errorCode: AuthErrorCode.missingContinueURI
    )
  }

  /** @fn testSuccessfulPasswordResetResponse
      @brief This test simulates a complete password reset response (with OOB Code) and makes sure
          it succeeds, and we get the OOB Code decoded correctly.
   */
  func testSuccessfulOOBResponse() async throws {
    for request in [
      getPasswordResetRequest,
      getSignInWithEmailRequest,
      getEmailVerificationRequest,
    ] {
      rpcIssuer?.respondBlock = {
        try self.rpcIssuer?.respond(withJSON: [self.kOOBCodeKey: self.kTestOOBCode])
      }
      let response = try await AuthBackend.call(with: request())
      XCTAssertEqual(response.OOBCode, kTestOOBCode)
    }
  }

  /** @fn testSuccessfulPasswordResetResponseWithoutOOBCode
      @brief This test simulates a password reset request where we don't receive the optional OOBCode
          response value. It should still succeed.
   */
  func testSuccessfulOOBResponseWithoutOOBCode() async throws {
    for request in [
      getPasswordResetRequest,
      getSignInWithEmailRequest,
      getEmailVerificationRequest,
    ] {
      rpcIssuer?.respondBlock = {
        try self.rpcIssuer?.respond(withJSON: [:])
      }
      let response = try await AuthBackend.call(with: request())
      XCTAssertNil(response.OOBCode)
    }
  }

  private func getPasswordResetRequest() throws -> GetOOBConfirmationCodeRequest {
    return try XCTUnwrap(GetOOBConfirmationCodeRequest.passwordResetRequest(
      email: kTestEmail,
      actionCodeSettings: fakeActionCodeSettings(),
      requestConfiguration: makeRequestConfiguration()
    ))
  }

  private func getSignInWithEmailRequest() throws -> GetOOBConfirmationCodeRequest {
    return try XCTUnwrap(GetOOBConfirmationCodeRequest.signInWithEmailLinkRequest(
      kTestEmail,
      actionCodeSettings: fakeActionCodeSettings(),
      requestConfiguration: makeRequestConfiguration()
    ))
  }

  private func getEmailVerificationRequest() throws -> GetOOBConfirmationCodeRequest {
    return try XCTUnwrap(GetOOBConfirmationCodeRequest
      .verifyEmailRequest(accessToken: kTestAccessToken,
                          actionCodeSettings: fakeActionCodeSettings(),
                          requestConfiguration: makeRequestConfiguration()))
  }
}
