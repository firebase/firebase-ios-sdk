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

#if os(iOS)
/**
   @brief Utility class for constructing Phone Sign In credentials.
*/
@objc(FIRPhoneAuthProvider) open class PhoneAuthProvider: NSObject {

  @objc static public let id = "phone"

  /**
      @brief Returns an instance of `PhoneAuthProvider` for the default `Auth` object.
   */
  @objc(provider) public class func provider() -> PhoneAuthProvider {
    return PhoneAuthProvider(auth: Auth.auth())
  }

  /**
      @brief Returns an instance of `PhoneAuthProvider` for the provided `Auth` object.
      @param auth The auth object to associate with the phone auth provider instance.
   */
  @objc(providerWithAuth:) public class func provider(auth: Auth) -> PhoneAuthProvider {
    return PhoneAuthProvider(auth: auth)
  }

  /**
      @brief Starts the phone number authentication flow by sending a verification code to the
          specified phone number.
      @param phoneNumber The phone number to be verified.
      @param UIDelegate An object used to present the SFSafariViewController. The object is retained
          by this method until the completion block is executed.
      @param completion The callback to be invoked when the verification flow is finished.
      @remarks Possible error codes:

          + `AuthErrorCodeCaptchaCheckFailed` - Indicates that the reCAPTCHA token obtained by
              the Firebase Auth is invalid or has expired.
          + `AuthErrorCodeQuotaExceeded` - Indicates that the phone verification quota for this
              project has been exceeded.
          + `AuthErrorCodeInvalidPhoneNumber` - Indicates that the phone number provided is
              invalid.
          + `AuthErrorCodeMissingPhoneNumber` - Indicates that a phone number was not provided.
   */
  @objc(verifyPhoneNumber:UIDelegate:completion:)
  public func verify(phoneNumber: String, UIDelegate: AuthUIDelegate?,
                     completion: ((_: String?, _: Error?) -> Void)?) {
// TODO

  }

  /**
      @brief Verify ownership of the second factor phone number by the current user.
      @param phoneNumber The phone number to be verified.
      @param UIDelegate An object used to present the SFSafariViewController. The object is retained
          by this method until the completion block is executed.
      @param session A session to identify the MFA flow. For enrollment, this identifies the user
          trying to enroll. For sign-in, this identifies that the user already passed the first
          factor challenge.
      @param completion The callback to be invoked when the verification flow is finished.
  */
  @objc(verifyPhoneNumber:UIDelegate:multiFactorSession:completion:)
  public func verify(phoneNumber: String, UIDelegate: AuthUIDelegate?,
                     session: MultiFactorSession?,
                     completion: ((_: String?, _: Error?) -> Void)?) {
// TODO

  }

  /**
      @brief Verify ownership of the second factor phone number by the current user.
      @param phoneMultiFactorInfo The phone multi factor whose number need to be verified.
      @param UIDelegate An object used to present the SFSafariViewController. The object is retained
          by this method until the completion block is executed.
      @param session A session to identify the MFA flow. For enrollment, this identifies the user
          trying to enroll. For sign-in, this identifies that the user already passed the first
          factor challenge.
      @param completion The callback to be invoked when the verification flow is finished.
  */
  @objc(verifyPhoneNumberWithMultiFactorInfo:UIDelegate:multiFactorSession:completion:)
  public func verify(phoneMultiFactorInfo: PhoneMultiFactorInfo, UIDelegate: AuthUIDelegate?,
                     session: MultiFactorSession?,
                     completion: ((_: String?, _: Error?) -> Void)?) {
// TODO

  }

  /**
      @brief Creates an `AuthCredential` for the phone number provider identified by the
          verification ID and verification code.

      @param verificationID The verification ID obtained from invoking
          verifyPhoneNumber:completion:
      @param verificationCode The verification code obtained from the user.
      @return The corresponding phone auth credential for the verification ID and verification code
          provided.
   */
  @objc(credentialWithVerificationID:verificationCode:)
  func credential(verificationID: String, verificationCode:String) -> AuthCredential {
    return PhoneAuthCredential(withProviderID: PhoneAuthProvider.id,
                               verificationID: verificationID,
                               verificationCode: verificationCode)
  }

  private let auth: Auth
  private let callbackScheme: String
  private let usingClientIDScheme: Bool

  private init(auth: Auth) {
    self.auth = auth
    //if auth.app
    self.callbackScheme = "todo"
    self.usingClientIDScheme = false
  }
}

@objc(FIRPhoneAuthCredential) public class PhoneAuthCredential: AuthCredential, NSSecureCoding {
  // TODO: delete objc's and public's below
  @objc public let temporaryProof: String?
  @objc public let phoneNumber: String?
  @objc public let verificationID: String?
  @objc public let verificationCode: String?

  // TODO: Remove public objc
  @objc public init(withTemporaryProof temporaryProof:String, phoneNumber: String, providerID: String) {
    self.temporaryProof = temporaryProof
    self.phoneNumber = phoneNumber
    self.verificationID = nil
    self.verificationCode = nil
    super.init(provider: providerID)
  }

  init(withProviderID providerID:String, verificationID: String, verificationCode: String) {
    self.verificationID = verificationID
    self.verificationCode = verificationCode
    self.temporaryProof = nil
    self.phoneNumber = nil
    super.init(provider: providerID)
  }

  public static var supportsSecureCoding = true

  public func encode(with coder: NSCoder) {
    coder.encode(verificationID)
    coder.encode(verificationCode)
    coder.encode(temporaryProof)
    coder.encode(phoneNumber)
  }

  required public init?(coder: NSCoder) {
    let verificationID = coder.decodeObject(forKey: "verificationID") as? String
    let verificationCode = coder.decodeObject(forKey: "verificationCode") as? String
    let temporaryProof = coder.decodeObject(forKey: "temporaryProof") as? String
    let phoneNumber = coder.decodeObject(forKey: "phoneNumber") as? String
    if let temporaryProof = temporaryProof,
       let phoneNumber = phoneNumber {
      self.temporaryProof = temporaryProof
      self.phoneNumber = phoneNumber
      self.verificationID = nil
      self.verificationCode = nil
      super.init(provider: PhoneAuthProvider.id)
    } else if let verificationID = verificationID,
              let verificationCode = verificationCode {
      self.verificationID = verificationID
      self.verificationCode = verificationCode
      self.temporaryProof = nil
      self.phoneNumber = nil
      super.init(provider: PhoneAuthProvider.id)
    } else {
      return nil
    }
  }
}
#endif // iOS
