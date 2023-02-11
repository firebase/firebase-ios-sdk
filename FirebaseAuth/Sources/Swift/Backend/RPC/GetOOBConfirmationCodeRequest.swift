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

enum GetOOBConfirmationCodeRequestType: Int {
  /** @var FIRGetOOBConfirmationCodeRequestTypePasswordReset
      @brief Requests a password reset code.
   */
  case passwordReset

  /** @var FIRGetOOBConfirmationCodeRequestTypeVerifyEmail
      @brief Requests an email verification code.
   */
  case verifyEmail

  /** @var FIRGetOOBConfirmationCodeRequestTypeEmailLink
      @brief Requests an email sign-in link.
   */
  case emailLink

  /** @var FIRGetOOBConfirmationCodeRequestTypeVerifyBeforeUpdateEmail
      @brief Requests an verify before update email.
   */
  case verifyBeforeUpdateEmail

  var value: String {
    switch self {
    case .passwordReset:
      return kPasswordResetRequestTypeValue
    case .verifyEmail:
      return kVerifyEmailRequestTypeValue
    case .emailLink:
      return kEmailLinkSignInTypeValue
    case .verifyBeforeUpdateEmail:
      return kVerifyBeforeUpdateEmailRequestTypeValue
    }
  }
}

private let kGetOobConfirmationCodeEndpoint = "getOobConfirmationCode"

/** @var kRequestTypeKey
    @brief The name of the required "requestType" property in the request.
 */
private let kRequestTypeKey = "requestType"

/** @var kEmailKey
    @brief The name of the "email" property in the request.
 */
private let kEmailKey = "email"

/** @var kNewEmailKey
    @brief The name of the "newEmail" property in the request.
 */
private let kNewEmailKey = "newEmail"

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
private let kIDTokenKey = "idToken"

/** @var kContinueURLKey
    @brief The key for the "continue URL" value in the request.
 */
private let kContinueURLKey = "continueUrl"

/** @var kIosBundeIDKey
    @brief The key for the "iOS Bundle Identifier" value in the request.
 */
private let kIosBundleIDKey = "iOSBundleId"

/** @var kAndroidPackageNameKey
    @brief The key for the "Android Package Name" value in the request.
 */
private let kAndroidPackageNameKey = "androidPackageName"

/** @var kAndroidInstallAppKey
    @brief The key for the request parameter indicating whether the android app should be installed
        or not.
 */
private let kAndroidInstallAppKey = "androidInstallApp"

/** @var kAndroidMinimumVersionKey
    @brief The key for the "minimum Android version supported" value in the request.
 */
private let kAndroidMinimumVersionKey = "androidMinimumVersion"

/** @var kCanHandleCodeInAppKey
    @brief The key for the request parameter indicating whether the action code can be handled in
        the app or not.
 */
private let kCanHandleCodeInAppKey = "canHandleCodeInApp"

/** @var kDynamicLinkDomainKey
    @brief The key for the "dynamic link domain" value in the request.
 */
private let kDynamicLinkDomainKey = "dynamicLinkDomain"

/** @var kPasswordResetRequestTypeValue
    @brief The value for the "PASSWORD_RESET" request type.
 */
private let kPasswordResetRequestTypeValue = "PASSWORD_RESET"

/** @var kEmailLinkSignInTypeValue
    @brief The value for the "EMAIL_SIGNIN" request type.
 */
private let kEmailLinkSignInTypeValue = "EMAIL_SIGNIN"

/** @var kVerifyEmailRequestTypeValue
    @brief The value for the "VERIFY_EMAIL" request type.
 */
private let kVerifyEmailRequestTypeValue = "VERIFY_EMAIL"

/** @var kVerifyBeforeUpdateEmailRequestTypeValue
    @brief The value for the "VERIFY_AND_CHANGE_EMAIL" request type.
 */
private let kVerifyBeforeUpdateEmailRequestTypeValue = "VERIFY_AND_CHANGE_EMAIL"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

@objc(FIRGetOOBConfirmationCodeRequest)
public class GetOOBConfirmationCodeRequest: IdentityToolkitRequest,
  AuthRPCRequest {
  /** @property requestType
      @brief The types of OOB Confirmation Code to request.
   */
  let requestType: GetOOBConfirmationCodeRequestType

  /** @property email
      @brief The email of the user.
      @remarks For password reset.
   */
  @objc public var email: String?

  /** @property updatedEmail
      @brief The new email to be updated.
      @remarks For verifyBeforeUpdateEmail.
   */
  @objc public var updatedEmail: String?

  /** @property accessToken
      @brief The STS Access Token of the authenticated user.
      @remarks For email change.
   */
  @objc public var accessToken: String?

  /** @property continueURL
      @brief This URL represents the state/Continue URL in the form of a universal link.
   */
  @objc public var continueURL: String?

  /** @property iOSBundleID
      @brief The iOS bundle Identifier, if available.
   */
  @objc public var iOSBundleID: String?

  /** @property androidPackageName
      @brief The Android package name, if available.
   */
  @objc public var androidPackageName: String?

  /** @property androidMinimumVersion
      @brief The minimum Android version supported, if available.
   */
  @objc public var androidMinimumVersion: String?

  /** @property androidInstallIfNotAvailable
      @brief Indicates whether or not the Android app should be installed if not already available.
   */
  @objc public var androidInstallApp: Bool

  /** @property handleCodeInApp
      @brief Indicates whether the action code link will open the app directly or after being
          redirected from a Firebase owned web widget.
   */
  @objc public var handleCodeInApp: Bool

  /** @property dynamicLinkDomain
      @brief The Firebase Dynamic Link domain used for out of band code flow.
   */
  @objc public var dynamicLinkDomain: String?

  /** @var response
      @brief The corresponding response for this request
   */
  @objc public var response: AuthRPCResponse = GetOOBConfirmationCodeResponse()

  /** @fn initWithRequestType:email:APIKey:
      @brief Designated initializer.
      @param requestType The types of OOB Confirmation Code to request.
      @param email The email of the user.
      @param newEmail The email of the user to be updated.
      @param accessToken The STS Access Token of the currently signed in user.
      @param actionCodeSettings An object of FIRActionCodeSettings which specifies action code
          settings to be applied to the OOB code request.
      @param requestConfiguration An object containing configurations to be added to the request.
   */
  required init(requestType: GetOOBConfirmationCodeRequestType,
                email: String?,
                newEmail: String?,
                accessToken: String?,
                actionCodeSettings: ActionCodeSettings?,
                requestConfiguration: AuthRequestConfiguration) {
    self.requestType = requestType
    self.email = email
    updatedEmail = newEmail
    self.accessToken = accessToken
    continueURL = actionCodeSettings?.URL?.absoluteString
    iOSBundleID = actionCodeSettings?.iOSBundleID
    androidPackageName = actionCodeSettings?.androidPackageName
    androidMinimumVersion = actionCodeSettings?.androidMinimumVersion
    androidInstallApp = actionCodeSettings?.androidInstallIfNotAvailable ?? false
    handleCodeInApp = actionCodeSettings?.handleCodeInApp ?? false
    dynamicLinkDomain = actionCodeSettings?.dynamicLinkDomain

    super.init(
      endpoint: kGetOobConfirmationCodeEndpoint,
      requestConfiguration: requestConfiguration
    )
  }

  @objc public static func passwordResetRequest(email: String,
                                                actionCodeSettings: ActionCodeSettings?,
                                                requestConfiguration: AuthRequestConfiguration) ->
    GetOOBConfirmationCodeRequest? {
    Self(requestType: .passwordReset,
         email: email,
         newEmail: nil,
         accessToken: nil,
         actionCodeSettings: actionCodeSettings,
         requestConfiguration: requestConfiguration)
  }

  @objc public static func verifyEmailRequest(accessToken: String,
                                              actionCodeSettings: ActionCodeSettings?,
                                              requestConfiguration: AuthRequestConfiguration) ->
    GetOOBConfirmationCodeRequest? {
    Self(requestType: .verifyEmail,
         email: nil,
         newEmail: nil,
         accessToken: accessToken,
         actionCodeSettings: actionCodeSettings,
         requestConfiguration: requestConfiguration)
  }

  @objc public static func signInWithEmailLinkRequest(_ email: String,
                                                      actionCodeSettings: ActionCodeSettings?,
                                                      requestConfiguration: AuthRequestConfiguration)
    -> Self? {
    Self(requestType: .emailLink,
         email: email,
         newEmail: nil,
         accessToken: nil,
         actionCodeSettings: actionCodeSettings,
         requestConfiguration: requestConfiguration)
  }

  @objc public static func verifyBeforeUpdateEmail(accessToken: String,
                                                   newEmail: String,
                                                   actionCodeSettings: ActionCodeSettings?,
                                                   requestConfiguration: AuthRequestConfiguration)
    -> Self? {
    Self(requestType: .verifyBeforeUpdateEmail,
         email: nil,
         newEmail: newEmail,
         accessToken: accessToken,
         actionCodeSettings: actionCodeSettings,
         requestConfiguration: requestConfiguration)
  }

  public func unencodedHTTPRequestBody() throws -> Any {
    var body: [String: Any] = [
      kRequestTypeKey: requestType.value,
    ]

    // For password reset requests, we only need an email address in addition to the already required
    // fields.
    if case .passwordReset = requestType {
      body[kEmailKey] = email
    }

    // For verify email requests, we only need an STS Access Token in addition to the already required
    // fields.
    if case .verifyEmail = requestType {
      body[kIDTokenKey] = accessToken
    }

    // For email sign-in link requests, we only need an email address in addition to the already
    // required fields.
    if case .emailLink = requestType {
      body[kEmailKey] = email
    }

    // For email sign-in link requests, we only need an STS Access Token, a new email address in
    // addition to the already required fields.
    if case .verifyBeforeUpdateEmail = requestType {
      body[kNewEmailKey] = updatedEmail
      body[kIDTokenKey] = accessToken
    }

    if let continueURL = continueURL {
      body[kContinueURLKey] = continueURL
    }

    if let iOSBundleID = iOSBundleID {
      body[kIosBundleIDKey] = iOSBundleID
    }

    if let androidPackageName = androidPackageName {
      body[kAndroidPackageNameKey] = androidPackageName
    }

    if let androidMinimumVersion = androidMinimumVersion {
      body[kAndroidMinimumVersionKey] = androidMinimumVersion
    }

    if androidInstallApp {
      body[kAndroidInstallAppKey] = true
    }

    if handleCodeInApp {
      body[kCanHandleCodeInAppKey] = true
    }

    if let dynamicLinkDomain = dynamicLinkDomain {
      body[kDynamicLinkDomainKey] = dynamicLinkDomain
    }
    if let tenantID = tenantID {
      body[kTenantIDKey] = tenantID
    }

    return body
  }
}
