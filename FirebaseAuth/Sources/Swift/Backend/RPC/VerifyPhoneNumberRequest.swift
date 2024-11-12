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

/// The "verifyPhoneNumber" endpoint.
private let kVerifyPhoneNumberEndPoint = "verifyPhoneNumber"

/// The key for the verification ID parameter in the request.
private let kVerificationIDKey = "sessionInfo"

/// The key for the verification code parameter in the request.
private let kVerificationCodeKey = "code"

/// The key for the "ID Token" value in the request.
private let kIDTokenKey = "idToken"

/// The key for the temporary proof value in the request.
private let kTemporaryProofKey = "temporaryProof"

/// The key for the phone number value in the request.
private let kPhoneNumberKey = "phoneNumber"

/// The key for the operation value in the request.
private let kOperationKey = "operation"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

extension AuthOperationType {
  /// - Returns: The string value corresponding to the AuthOperationType.
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

  /// The verification ID obtained from the response of `sendVerificationCode`.
  let verificationID: String?

  /// The verification code provided by the user.
  let verificationCode: String?

  /// The STS Access Token for the authenticated user.
  var accessToken: String?

  /// The temporary proof code, previously returned from the backend.
  let temporaryProof: String?

  /// The phone number to be verified in the request.
  let phoneNumber: String?

  /// The type of operation triggering this verify phone number request.
  let operation: AuthOperationType

  /// Convenience initializer.
  /// - Parameter temporaryProof: The temporary proof sent by the backed.
  /// - Parameter phoneNumber: The phone number associated with the credential to be signed in .
  /// - Parameter operation: Indicates what operation triggered the verify phone number request.
  /// - Parameter requestConfiguration: An object containing configurations to be added to the
  /// request.
  convenience init(temporaryProof: String, phoneNumber: String, operation: AuthOperationType,
                   requestConfiguration: AuthRequestConfiguration) {
    self.init(
      temporaryProof: temporaryProof,
      phoneNumber: phoneNumber,
      verificationID: nil,
      verificationCode: nil,
      operation: operation,
      requestConfiguration: requestConfiguration
    )
  }

  /// Convenience initializer.
  /// - Parameter verificationID: The verification ID obtained from the response of
  /// `sendVerificationCode`.
  /// - Parameter verificationCode: The verification code provided by the user.
  /// - Parameter operation: Indicates what operation triggered the verify phone number request.
  /// - Parameter requestConfiguration: An object containing configurations to be added to the
  /// request.
  convenience init(verificationID: String,
                   verificationCode: String,
                   operation: AuthOperationType,
                   requestConfiguration: AuthRequestConfiguration) {
    self.init(
      temporaryProof: nil,
      phoneNumber: nil,
      verificationID: verificationID,
      verificationCode: verificationCode,
      operation: operation,
      requestConfiguration: requestConfiguration
    )
  }

  private init(temporaryProof: String?, phoneNumber: String?, verificationID: String?,
               verificationCode: String?, operation: AuthOperationType,
               requestConfiguration: AuthRequestConfiguration) {
    self.temporaryProof = temporaryProof
    self.phoneNumber = phoneNumber
    self.verificationID = verificationID
    self.verificationCode = verificationCode
    self.operation = operation
    super.init(
      endpoint: kVerifyPhoneNumberEndPoint,
      requestConfiguration: requestConfiguration,
      useIdentityPlatform: false,
      useStaging: false
    )
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
