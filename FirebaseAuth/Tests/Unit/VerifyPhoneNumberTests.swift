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

#if os(iOS)
  class VerifyPhoneNumberTests: RPCBaseTests {
    private let kVerificationCode = "12345678"
    private let kVerificationID = "55432"
    private let kPhoneNumber = "4155551234"
    private let kTemporaryProof = "12345658"
    private let kVerificationCodeKey = "code"
    private let kVerificationIDKey = "sessionInfo"
    private let kIDTokenKey = "idToken"
    private let kOperationKey = "operation"
    private let kTestAccessToken = "accessToken"
    private let kTemporaryProofKey = "temporaryProof"
    private let kPhoneNumberKey = "phoneNumber"
    private let kExpectedAPIURL =
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPhoneNumber?key=APIKey"

    /** @fn testVerifyPhoneNumberRequest
        @brief Tests the verifyPhoneNumber request.
     */
    func testVerifyPhoneNumberRequest() throws {
      let request = makeVerifyPhoneNumberRequest()
      request.accessToken = kTestAccessToken
      let issuer = try checkRequest(
        request: request,
        expected: kExpectedAPIURL,
        key: kVerificationIDKey,
        value: kVerificationID
      )
      let requestDictionary = try XCTUnwrap(issuer.decodedRequest as? [String: AnyHashable])
      XCTAssertEqual(requestDictionary[kVerificationCodeKey], kVerificationCode)
      XCTAssertEqual(requestDictionary[kIDTokenKey], kTestAccessToken)
      XCTAssertEqual(
        requestDictionary[kOperationKey],
        AuthOperationType.signUpOrSignIn.operationString
      )
    }

    /** @fn testVerifyPhoneNumberRequestWithTemporaryProof
        @brief Tests the verifyPhoneNumber request when created using a temporary proof.
     */
    func testVerifyPhoneNumberRequestWithTemporaryProof() throws {
      let request = makeVerifyPhoneNumberRequestWithTemporaryProof()
      request.accessToken = kTestAccessToken
      let issuer = try checkRequest(
        request: request,
        expected: kExpectedAPIURL,
        key: kTemporaryProofKey,
        value: kTemporaryProof
      )
      let requestDictionary = try XCTUnwrap(issuer.decodedRequest as? [String: AnyHashable])
      XCTAssertEqual(requestDictionary[kPhoneNumberKey], kPhoneNumber)
      XCTAssertEqual(requestDictionary[kIDTokenKey], kTestAccessToken)
      XCTAssertEqual(
        requestDictionary[kOperationKey],
        AuthOperationType.signUpOrSignIn.operationString
      )
    }

    func testVerifyPhoneNumberRequestErrors() throws {
      let kInvalidVerificationCodeErrorMessage = "INVALID_CODE"
      let kInvalidSessionInfoErrorMessage = "INVALID_SESSION_INFO"
      let kSessionExpiredErrorMessage = "SESSION_EXPIRED"

      try checkBackendError(
        request: makeVerifyPhoneNumberRequest(),
        message: kInvalidVerificationCodeErrorMessage,
        errorCode: AuthErrorCode.invalidVerificationCode
      )
      try checkBackendError(
        request: makeVerifyPhoneNumberRequest(),
        message: kInvalidSessionInfoErrorMessage,
        errorCode: AuthErrorCode.invalidVerificationID
      )
      try checkBackendError(
        request: makeVerifyPhoneNumberRequest(),
        message: kSessionExpiredErrorMessage,
        errorCode: AuthErrorCode.sessionExpired
      )
    }

    /** @fn testSuccessfulVerifyPhoneNumberResponse
        @brief Tests a successful to verify phone number flow.
     */
    func testSuccessfulVerifyPhoneNumberResponse() throws {
      let kTestLocalID = "testLocalId"
      let kTestIDToken = "ID_TOKEN"
      let kTestExpiresIn = "12345"
      let kTestRefreshToken = "REFRESH_TOKEN"
      var callbackInvoked = false
      var rpcResponse: VerifyPhoneNumberResponse?
      var rpcError: NSError?

      AuthBackend.post(with: makeVerifyPhoneNumberRequest()) { response, error in
        callbackInvoked = true
        rpcResponse = response
        rpcError = error as? NSError
      }

      _ = try rpcIssuer?.respond(withJSON: [
        "idToken": kTestIDToken,
        "refreshToken": kTestRefreshToken,
        "localId": kTestLocalID,
        "expiresIn": kTestExpiresIn,
        "isNewUser": true,
      ])

      XCTAssert(callbackInvoked)
      XCTAssertNil(rpcError)
      XCTAssertEqual(rpcResponse?.localID, kTestLocalID)
      XCTAssertEqual(rpcResponse?.idToken, kTestIDToken)
      let expiresIn = try XCTUnwrap(rpcResponse?.approximateExpirationDate?.timeIntervalSinceNow)
      XCTAssertEqual(expiresIn, 12345, accuracy: 0.1)
      XCTAssertEqual(rpcResponse?.refreshToken, kTestRefreshToken)
    }

    /** @fn testSuccessfulVerifyPhoneNumberResponseWithTemporaryProof
        @brief Tests a successful to verify phone number flow with temporary proof response.
     */
    func testSuccessfulVerifyPhoneNumberResponseWithTemporaryProof() throws {
      var callbackInvoked = false
      var rpcResponse: VerifyPhoneNumberResponse?
      var rpcError: NSError?

      AuthBackend
        .post(with: makeVerifyPhoneNumberRequestWithTemporaryProof()) { response, error in
          callbackInvoked = true
          rpcResponse = response
          rpcError = error as? NSError
        }

      _ = try rpcIssuer?.respond(withJSON: [
        "temporaryProof": kTemporaryProof,
        "phoneNumber": kPhoneNumber,
      ])

      XCTAssert(callbackInvoked)
      XCTAssertNil(rpcResponse)
      let credential = try XCTUnwrap(rpcError?
        .userInfo[AuthErrors.userInfoUpdatedCredentialKey] as? PhoneAuthCredential)
      XCTAssertEqual(credential.temporaryProof, kTemporaryProof)
      XCTAssertEqual(credential.phoneNumber, kPhoneNumber)
    }

    private func makeVerifyPhoneNumberRequest() -> VerifyPhoneNumberRequest {
      return VerifyPhoneNumberRequest(verificationID: kVerificationID,
                                      verificationCode: kVerificationCode,
                                      operation: AuthOperationType.signUpOrSignIn,
                                      requestConfiguration: makeRequestConfiguration())
    }

    private func makeVerifyPhoneNumberRequestWithTemporaryProof() -> VerifyPhoneNumberRequest {
      return VerifyPhoneNumberRequest(temporaryProof: kTemporaryProof,
                                      phoneNumber: kPhoneNumber,
                                      operation: AuthOperationType.signUpOrSignIn,
                                      requestConfiguration: makeRequestConfiguration())
    }
  }
#endif
