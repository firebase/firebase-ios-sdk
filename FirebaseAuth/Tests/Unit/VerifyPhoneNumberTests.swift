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
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
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
    func testVerifyPhoneNumberRequest() async throws {
      let request = makeVerifyPhoneNumberRequest()
      request.accessToken = kTestAccessToken
      try await checkRequest(
        request: request,
        expected: kExpectedAPIURL,
        key: kVerificationIDKey,
        value: kVerificationID
      )
      let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
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
    func testVerifyPhoneNumberRequestWithTemporaryProof() async throws {
      let request = makeVerifyPhoneNumberRequestWithTemporaryProof()
      request.accessToken = kTestAccessToken
      try await checkRequest(
        request: request,
        expected: kExpectedAPIURL,
        key: kTemporaryProofKey,
        value: kTemporaryProof
      )
      let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
      XCTAssertEqual(requestDictionary[kPhoneNumberKey], kPhoneNumber)
      XCTAssertEqual(requestDictionary[kIDTokenKey], kTestAccessToken)
      XCTAssertEqual(
        requestDictionary[kOperationKey],
        AuthOperationType.signUpOrSignIn.operationString
      )
    }

    func testVerifyPhoneNumberRequestErrors() async throws {
      let kInvalidVerificationCodeErrorMessage = "INVALID_CODE"
      let kInvalidSessionInfoErrorMessage = "INVALID_SESSION_INFO"
      let kSessionExpiredErrorMessage = "SESSION_EXPIRED"

      try await checkBackendError(
        request: makeVerifyPhoneNumberRequest(),
        message: kInvalidVerificationCodeErrorMessage,
        errorCode: AuthErrorCode.invalidVerificationCode
      )
      try await checkBackendError(
        request: makeVerifyPhoneNumberRequest(),
        message: kInvalidSessionInfoErrorMessage,
        errorCode: AuthErrorCode.invalidVerificationID
      )
      try await checkBackendError(
        request: makeVerifyPhoneNumberRequest(),
        message: kSessionExpiredErrorMessage,
        errorCode: AuthErrorCode.sessionExpired
      )
    }

    /** @fn testSuccessfulVerifyPhoneNumberResponse
     @brief Tests a successful to verify phone number flow.
     */
    func testSuccessfulVerifyPhoneNumberResponse() async throws {
      let kTestLocalID = "testLocalId"
      let kTestIDToken = "ID_TOKEN"
      let kTestExpiresIn = "12345"
      let kTestRefreshToken = "REFRESH_TOKEN"

      rpcIssuer.respondBlock = {
        try self.rpcIssuer?.respond(withJSON: [
          "idToken": kTestIDToken,
          "refreshToken": kTestRefreshToken,
          "localId": kTestLocalID,
          "expiresIn": kTestExpiresIn,
          "isNewUser": true,
        ])
      }
      let rpcResponse = try await AuthBackend.call(with: makeVerifyPhoneNumberRequest())
      XCTAssertEqual(rpcResponse.localID, kTestLocalID)
      XCTAssertEqual(rpcResponse.idToken, kTestIDToken)
      let expiresIn = try XCTUnwrap(rpcResponse.approximateExpirationDate?.timeIntervalSinceNow)
      XCTAssertEqual(expiresIn, 12345, accuracy: 0.1)
      XCTAssertEqual(rpcResponse.refreshToken, kTestRefreshToken)
    }

    /** @fn testSuccessfulVerifyPhoneNumberResponseWithTemporaryProof
        @brief Tests a successful to verify phone number flow with temporary proof response.
     */
    func testSuccessfulVerifyPhoneNumberResponseWithTemporaryProof() async throws {
      rpcIssuer.respondBlock = {
        try self.rpcIssuer?.respond(withJSON: [
          "temporaryProof": self.kTemporaryProof,
          "phoneNumber": self.kPhoneNumber,
        ])
      }
      do {
        let _ = try await AuthBackend.call(with: makeVerifyPhoneNumberRequestWithTemporaryProof())
        XCTFail("Expected to throw")
      } catch {
        let rpcError = error as NSError
        let credential = try XCTUnwrap(rpcError
          .userInfo[AuthErrors.userInfoUpdatedCredentialKey] as? PhoneAuthCredential)
        switch credential.credentialKind {
        case let .phoneNumber(phoneNumber, temporaryProof):
          XCTAssertEqual(temporaryProof, kTemporaryProof)
          XCTAssertEqual(phoneNumber, kPhoneNumber)
        case .verification: XCTFail("Should be phoneNumber case")
        }
      }
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
