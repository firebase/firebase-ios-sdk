//
//  File.swift
//
//
//  Created by Morten Bek Ditlevsen on 20/01/2023.
//

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

@objc(FIRVerifyPhoneNumberRequest) public class VerifyPhoneNumberRequest: IdentityToolkitRequest,
  AuthRPCRequest {
  /** @property verificationID
       @brief The verification ID obtained from the response of @c sendVerificationCode.
   */
  @objc public var verificationID: String?

  /** @property verificationCode
       @brief The verification code provided by the user.
   */
  @objc public var verificationCode: String?

  /** @property accessToken
      @brief The STS Access Token for the authenticated user.
   */
  @objc public var accessToken: String?

  /** @var temporaryProof
      @brief The temporary proof code, previously returned from the backend.
   */
  @objc public var temporaryProof: String?

  /** @var phoneNumber
      @brief The phone number to be verified in the request.
   */
  @objc public var phoneNumber: String?

  /** @var operation
      @brief The type of operation triggering this verify phone number request.
   */
  @objc public var operation: AuthOperationType

  /** @fn initWithTemporaryProof:phoneNumberAPIKey
      @brief Designated initializer.
      @param temporaryProof The temporary proof sent by the backed.
      @param phoneNumber The phone number associated with the credential to be signed in.
      @param operation Indicates what operation triggered the verify phone number request.
      @param requestConfiguration An object containing configurations to be added to the request.
   */
  @objc public init(temporaryProof: String, phoneNumber: String, operation: AuthOperationType,
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
  @objc public init(verificationID: String,
                    verificationCode: String,
                    operation: AuthOperationType,
                    requestConfiguration: AuthRequestConfiguration) {
    self.verificationID = verificationID
    self.verificationCode = verificationCode
    self.operation = operation
    super.init(endpoint: kVerifyPhoneNumberEndPoint, requestConfiguration: requestConfiguration)
  }

  public func unencodedHTTPRequestBody() throws -> Any {
    var postBody: [String: Any] = [:]
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
