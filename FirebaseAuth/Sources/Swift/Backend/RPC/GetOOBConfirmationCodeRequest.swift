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
  /// Requests a password reset code.
  case passwordReset

  /// Requests an email verification code.
  case verifyEmail

  /// Requests an email sign-in link.
  case emailLink

  /// Requests a verify before update email.
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

/// The name of the required "requestType" property in the request.
private let kRequestTypeKey = "requestType"

/// The name of the "email" property in the request.
private let kEmailKey = "email"

/// The name of the "newEmail" property in the request.
private let kNewEmailKey = "newEmail"

/// The key for the "idToken" value in the request. This is actually the STS Access Token,
/// despite its confusing (backwards compatible) parameter name.
private let kIDTokenKey = "idToken"

/// The key for the "continue URL" value in the request.
private let kContinueURLKey = "continueUrl"

/// The key for the "iOS Bundle Identifier" value in the request.
private let kIosBundleIDKey = "iOSBundleId"

/// The key for the "Android Package Name" value in the request.
private let kAndroidPackageNameKey = "androidPackageName"

/// The key for the request parameter indicating whether the android app should be installed or not.
private let kAndroidInstallAppKey = "androidInstallApp"

/// The key for the "minimum Android version supported" value in the request.
private let kAndroidMinimumVersionKey = "androidMinimumVersion"

/// The key for the request parameter indicating whether the action code can be handled in the app
/// or not.
private let kCanHandleCodeInAppKey = "canHandleCodeInApp"

/// The key for the "dynamic link domain" value in the request.
private let kDynamicLinkDomainKey = "dynamicLinkDomain"

/// The value for the "PASSWORD_RESET" request type.
private let kPasswordResetRequestTypeValue = "PASSWORD_RESET"

/// The value for the "EMAIL_SIGNIN" request type.
private let kEmailLinkSignInTypeValue = "EMAIL_SIGNIN"

/// The value for the "VERIFY_EMAIL" request type.
private let kVerifyEmailRequestTypeValue = "VERIFY_EMAIL"

/// The value for the "VERIFY_AND_CHANGE_EMAIL" request type.
private let kVerifyBeforeUpdateEmailRequestTypeValue = "VERIFY_AND_CHANGE_EMAIL"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

/// The key for the "captchaResponse" value in the request.
private let kCaptchaResponseKey = "captchaResp"

/// The key for the "clientType" value in the request.
private let kClientType = "clientType"

/// The key for the "recaptchaVersion" value in the request.
private let kRecaptchaVersion = "recaptchaVersion"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class GetOOBConfirmationCodeRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = GetOOBConfirmationCodeResponse

  /// The types of OOB Confirmation Code to request.
  let requestType: GetOOBConfirmationCodeRequestType

  /// The email of the user for password reset.
  private(set) var email: String?

  /// The new email to be updated for verifyBeforeUpdateEmail.
  private(set) var updatedEmail: String?

  /// The STS Access Token of the authenticated user for email change.
  private(set) var accessToken: String?

  /// This URL represents the state/Continue URL in the form of a universal link.
  private(set) var continueURL: String?

  /// The iOS bundle Identifier, if available.
  private(set) var iOSBundleID: String?

  /// The Android package name, if available.
  private(set) var androidPackageName: String?

  /// The minimum Android version supported, if available.
  private(set) var androidMinimumVersion: String?

  /// Indicates whether or not the Android app should be installed if not already available.
  private(set) var androidInstallApp: Bool

  /// Indicates whether the action code link will open the app directly or after being
  ///   redirected from a Firebase owned web widget.
  private(set) var handleCodeInApp: Bool

  /// The Firebase Dynamic Link domain used for out of band code flow.
  private(set) var dynamicLinkDomain: String?

  /// Response to the captcha.
  var captchaResponse: String?

  /// The reCAPTCHA version.
  var recaptchaVersion: String?

  /// Designated initializer.
  /// - Parameter requestType: The types of OOB Confirmation Code to request.
  /// - Parameter email: The email of the user.
  /// - Parameter newEmail: The email of the user to be updated.
  /// - Parameter accessToken: The STS Access Token of the currently signed in user.
  /// - Parameter actionCodeSettings: An object of FIRActionCodeSettings which specifies action code
  ///    settings to be applied to the OOB code request.
  /// - Parameter requestConfiguration: An object containing configurations to be added to the
  /// request.
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
    continueURL = actionCodeSettings?.url?.absoluteString
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

  static func passwordResetRequest(email: String,
                                   actionCodeSettings: ActionCodeSettings?,
                                   requestConfiguration: AuthRequestConfiguration) ->
    GetOOBConfirmationCodeRequest {
    Self(requestType: .passwordReset,
         email: email,
         newEmail: nil,
         accessToken: nil,
         actionCodeSettings: actionCodeSettings,
         requestConfiguration: requestConfiguration)
  }

  static func verifyEmailRequest(accessToken: String,
                                 actionCodeSettings: ActionCodeSettings?,
                                 requestConfiguration: AuthRequestConfiguration) ->
    GetOOBConfirmationCodeRequest {
    Self(requestType: .verifyEmail,
         email: nil,
         newEmail: nil,
         accessToken: accessToken,
         actionCodeSettings: actionCodeSettings,
         requestConfiguration: requestConfiguration)
  }

  static func signInWithEmailLinkRequest(_ email: String,
                                         actionCodeSettings: ActionCodeSettings?,
                                         requestConfiguration: AuthRequestConfiguration)
    -> Self {
    Self(requestType: .emailLink,
         email: email,
         newEmail: nil,
         accessToken: nil,
         actionCodeSettings: actionCodeSettings,
         requestConfiguration: requestConfiguration)
  }

  static func verifyBeforeUpdateEmail(accessToken: String,
                                      newEmail: String,
                                      actionCodeSettings: ActionCodeSettings?,
                                      requestConfiguration: AuthRequestConfiguration)
    -> Self {
    Self(requestType: .verifyBeforeUpdateEmail,
         email: nil,
         newEmail: newEmail,
         accessToken: accessToken,
         actionCodeSettings: actionCodeSettings,
         requestConfiguration: requestConfiguration)
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var body: [String: AnyHashable] = [
      kRequestTypeKey: requestType.value,
    ]
    // For password reset requests, we only need an email address in addition to the already
    // required fields.
    if case .passwordReset = requestType {
      body[kEmailKey] = email
    }
    // For verify email requests, we only need an STS Access Token in addition to the already
    // required fields.
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
    if let dynamicLinkDomain {
      body[kDynamicLinkDomainKey] = dynamicLinkDomain
    }
    if let captchaResponse {
      body[kCaptchaResponseKey] = captchaResponse
    }
    body[kClientType] = clientType
    if let recaptchaVersion {
      body[kRecaptchaVersion] = recaptchaVersion
    }
    if let tenantID {
      body[kTenantIDKey] = tenantID
    }
    return body
  }

  func injectRecaptchaFields(recaptchaResponse: String?, recaptchaVersion: String) {
    captchaResponse = recaptchaResponse
    self.recaptchaVersion = recaptchaVersion
  }
}
