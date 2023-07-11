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

/** @var kVerifyPhoneNumberEndPoint
    @brief The "verifyPhoneNumber" endpoint.
 */
private let kVerifyPhoneNumberEndPoint = "verifyPhoneNumber"

/** @var kVerificationIDKey
    @brief The key for the verification ID parameter in the request.
 */
private let kVerificationIDKey = "sessionInfo"

/** @var kVerificationCodeKey
    @brief The key for the verification code parameter in the request.
 */
private let kVerificationCodeKey = "code"

/** @var kIDTokenKey
    @brief The key for the "ID Token" value in the request.
 */
private let kIDTokenKey = "idToken"

/** @var kTemporaryProofKey
    @brief The key for the temporary proof value in the request.
 */
private let kTemporaryProofKey = "temporaryProof"

/** @var kPhoneNumberKey
    @brief The key for the phone number value in the request.
 */
private let kPhoneNumberKey = "phoneNumber"

/** @var kOperationKey
    @brief The key for the operation value in the request.
 */
private let kOperationKey = "operation"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

extension AuthOperationType {
  /** @fn FIRAuthOperationString
      @brief Returns a string object corresponding to the provided FIRAuthOperationType value.
      @param operationType The value of the FIRAuthOperationType enum which will be translated to its
          corresponding string value.
      @return The string value corresponding to the FIRAuthOperationType argument.
   */
  var operationString: String {
    switch self {
    case .unspecified:
      return "VERIFY_OP_UNSPECIFIED"
    case .signUpOrSignIn:
      return "SIGN_UP_OR_IN"
    case .reauth:
      return "REAUTH"
    case .link:
      return "LINK"
    case .update:
      return "UPDATE"
    }
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class VerifyPhoneNumberRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = VerifyPhoneNumberResponse

  /** @property verificationID
       @brief The verification ID obtained from the response of @c sendVerificationCode.
   */
  var verificationID: String?

  /** @property verificationCode
       @brief The verification code provided by the user.
   */
  var verificationCode: String?

  /** @property accessToken
      @brief The STS Access Token for the authenticated user.
   */
  var accessToken: String?

  /** @var temporaryProof
      @brief The temporary proof code, previously returned from the backend.
   */
  var temporaryProof: String?

  /** @var phoneNumber
      @brief The phone number to be verified in the request.
   */
  var phoneNumber: String?

  /** @var operation
      @brief The type of operation triggering this verify phone number request.
   */
  var operation: AuthOperationType

  /** @fn initWithTemporaryProof:phoneNumberAPIKey
      @brief Designated initializer.
      @param temporaryProof The temporary proof sent by the backed.
      @param phoneNumber The phone number associated with the credential to be signed in.
      @param operation Indicates what operation triggered the verify phone number request.
      @param requestConfiguration An object containing configurations to be added to the request.
   */
  init(temporaryProof: String, phoneNumber: String, operation: AuthOperationType,
       requestConfiguration: AuthRequestConfiguration) {
    self.temporaryProof = temporaryProof
    self.phoneNumber = phoneNumber
    self.operation = operation
    super.init(endpoint: kVerifyPhoneNumberEndPoint, requestConfiguration: requestConfiguration)
  }

  /** @fn initWithVerificationID:verificationCode:requestConfiguration
      @brief Designated initializer.
      @param verificationID The verification ID obtained from the response of @c sendVerificationCode.
      @param verificationCode The verification code provided by the user.
      @param operation Indicates what operation triggered the verify phone number request.
      @param requestConfiguration An object containing configurations to be added to the request.
   */
  init(verificationID: String,
       verificationCode: String,
       operation: AuthOperationType,
       requestConfiguration: AuthRequestConfiguration) {
    self.verificationID = verificationID
    self.verificationCode = verificationCode
    self.operation = operation
    super.init(endpoint: kVerifyPhoneNumberEndPoint, requestConfiguration: requestConfiguration)
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var postBody: [String: AnyHashable] = [:]
    if let verificationID {
      postBody[kVerificationIDKey] = verificationID
    }
    if let verificationCode {
      postBody[kVerificationCodeKey] = verificationCode
    }
    if let accessToken {
      postBody[kIDTokenKey] = accessToken
    }
    if let temporaryProof {
      postBody[kTemporaryProofKey] = temporaryProof
    }
    if let phoneNumber {
      postBody[kPhoneNumberKey] = phoneNumber
    }
    if let tenantID {
      postBody[kTenantIDKey] = tenantID
    }
    postBody[kOperationKey] = operation.operationString
    return postBody
  }
}
