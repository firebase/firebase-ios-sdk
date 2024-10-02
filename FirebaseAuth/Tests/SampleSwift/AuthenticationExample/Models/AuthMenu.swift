// Copyright 2020 Google LLC
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

import UIKit

/// Firebase Auth supported identity providers and other methods of authentication
enum AuthMenu: String {
  case settings = "Settings"
  case google = "google.com"
  case apple = "apple.com"
  case twitter = "twitter.com"
  case microsoft = "microsoft.com"
  case gitHub = "github.com"
  case yahoo = "yahoo.com"
  case linkedIn = "linkedin.com"
  case facebook = "facebook.com"
  case gameCenter = "gc.apple.com"
  case emailPassword = "password"
  case passwordless = "emailLink"
  case phoneNumber = "phone"
  case anonymous
  case custom
  case initRecaptcha
  case customAuthDomain
  case getToken
  case getTokenForceRefresh
  case addAuthStateChangeListener
  case removeLastAuthStateChangeListener
  case addIdTokenChangeListener
  case removeLastIdTokenChangeListener
  case verifyClient
  case deleteApp
  case actionType
  case continueURL
  case requestVerifyEmail
  case requestPasswordReset
  case resetPassword
  case checkActionCode
  case applyActionCode
  case verifyPasswordResetCode
  case phoneEnroll
  case totpEnroll
  case multifactorUnenroll

  // More intuitively named getter for `rawValue`.
  var id: String { rawValue }

  // The UI friendly name of the `AuthMenu`. Used for display.
  var name: String {
    switch self {
    case .settings:
      return "Settings"
    case .google:
      return "Google"
    case .apple:
      return "Apple"
    case .twitter:
      return "Twitter"
    case .microsoft:
      return "Microsoft"
    case .gitHub:
      return "GitHub"
    case .yahoo:
      return "Yahoo"
    case .linkedIn:
      return "LinkedIn"
    case .facebook:
      return "Facebook"
    case .gameCenter:
      return "Game Center"
    case .emailPassword:
      return "Email & Password Login"
    case .passwordless:
      return "Email Link/Passwordless"
    case .phoneNumber:
      return "Phone Number"
    case .anonymous:
      return "Anonymous Authentication"
    case .custom:
      return "Custom Auth System"
    // Recpatcha
    case .initRecaptcha:
      return "Initialize reCAPTCHA Enterprise"
    // Custom Auth Domain
    case .customAuthDomain:
      return "Set Custom Auth Domain"
    // App Section
    case .getToken:
      return "Get Token"
    case .getTokenForceRefresh:
      return "Get Token Force Refresh"
    case .addAuthStateChangeListener:
      return "Add Auth State Change Listener"
    case .removeLastAuthStateChangeListener:
      return "Remove Last Auth State Change Listener"
    case .addIdTokenChangeListener:
      return "Add ID Token Change Listener"
    case .removeLastIdTokenChangeListener:
      return "Remove Last ID Token Change Listener"
    case .verifyClient:
      return "Verify Client"
    case .deleteApp:
      return "Delete App"
    // OOB
    case .actionType:
      return "Action Type"
    case .continueURL:
      return "Continue URL"
    case .requestVerifyEmail:
      return "Request Verify Email"
    case .requestPasswordReset:
      return "Request Password Reset"
    case .resetPassword:
      return "Reset Password"
    case .checkActionCode:
      return "Check Action Code"
    case .applyActionCode:
      return "Apply Action Code"
    case .verifyPasswordResetCode:
      return "Verify Password Reset Code"
    // Multi factor
    case .phoneEnroll:
      return "Phone Enroll"
    case .totpEnroll:
      return "TOTP Enroll"
    case .multifactorUnenroll:
      return "Multifactor unenroll"
    }
  }

  // Failable initializer to create an `AuthMenu` from its corresponding `name` value.
  // - Parameter rawValue: String value representing `AuthMenu`'s name or type.
  init?(rawValue: String) {
    switch rawValue {
    case "Settings":
      self = .settings
    case "Google":
      self = .google
    case "Apple":
      self = .apple
    case "Twitter":
      self = .twitter
    case "Microsoft":
      self = .microsoft
    case "GitHub":
      self = .gitHub
    case "Yahoo":
      self = .yahoo
    case "LinkedIn":
      self = .linkedIn
    case "Facebook":
      self = .facebook
    case "Game Center":
      self = .gameCenter
    case "Email & Password Login":
      self = .emailPassword
    case "Email Link/Passwordless":
      self = .passwordless
    case "Phone Number":
      self = .phoneNumber
    case "Anonymous Authentication":
      self = .anonymous
    case "Custom Auth System":
      self = .custom
    case "Initialize reCAPTCHA Enterprise":
      self = .initRecaptcha
    case "Set Custom Auth Domain":
      self = .customAuthDomain
    case "Get Token":
      self = .getToken
    case "Get Token Force Refresh":
      self = .getTokenForceRefresh
    case "Add Auth State Change Listener":
      self = .addAuthStateChangeListener
    case "Remove Last Auth State Change Listener":
      self = .removeLastAuthStateChangeListener
    case "Add ID Token Change Listener":
      self = .addIdTokenChangeListener
    case "Remove Last ID Token Change Listener":
      self = .removeLastIdTokenChangeListener
    case "Verify Client":
      self = .verifyClient
    case "Delete App":
      self = .deleteApp
    case "Action Type":
      self = .actionType
    case "Continue URL":
      self = .continueURL
    case "Request Verify Email":
      self = .requestVerifyEmail
    case "Request Password Reset":
      self = .requestPasswordReset
    case "Reset Password":
      self = .resetPassword
    case "Check Action Code":
      self = .checkActionCode
    case "Apply Action Code":
      self = .applyActionCode
    case "Verify Password Reset Code":
      self = .verifyPasswordResetCode
    case "Phone Enroll":
      self = .phoneEnroll
    case "TOTP Enroll":
      self = .totpEnroll
    case "Multifactor unenroll":
      self = .multifactorUnenroll
    default:
      return nil
    }
  }
}

enum ActionCodeRequestType: String {
  case email
  case `continue`
  case inApp

  var name: String {
    switch self {
    case .email:
      return "Email Only"
    case .inApp:
      return "In-App + Continue URL"
    case .continue:
      return "Continue URL"
    }
  }

  init?(rawValue: String) {
    switch rawValue {
    case "Email Only":
      self = .email
    case "In-App + Continue URL":
      self = .inApp
    case "Continue URL":
      self = .continue
    default:
      return nil
    }
  }
}

// MARK: DataSourceProvidable

class AuthMenuData: DataSourceProvidable {
  private static var providers: [AuthMenu] {
    [.google, .apple, .twitter, .microsoft, .gitHub, .yahoo, .linkedIn, .facebook, .gameCenter]
  }

  static var settingsSection: Section {
    let header = "Auth Settings"
    let item = Item(title: AuthMenu.settings.name, hasNestedContent: true)
    return Section(headerDescription: header, items: [item])
  }

  static var providerSection: Section {
    let providers = self.providers.map { Item(title: $0.name) }
    let header = "Identity Providers"
    let footer = "Choose a login flow from one of the identity providers above."
    return Section(headerDescription: header, footerDescription: footer, items: providers)
  }

  static var emailPasswordSection: Section {
    let image = UIImage(named: "firebaseIcon")
    let header = "Email and Password Login"
    let item = Item(title: AuthMenu.emailPassword.name, hasNestedContent: true, image: image)
    return Section(headerDescription: header, items: [item])
  }

  static var otherSection: Section {
    let lockSymbol = UIImage.systemImage("lock.slash.fill", tintColor: .systemOrange)
    let phoneSymbol = UIImage.systemImage("phone.fill", tintColor: .systemOrange)
    let anonSymbol = UIImage.systemImage("questionmark.circle.fill", tintColor: .systemOrange)
    let shieldSymbol = UIImage.systemImage("lock.shield.fill", tintColor: .systemOrange)

    let otherOptions = [
      Item(title: AuthMenu.passwordless.name, image: lockSymbol),
      Item(title: AuthMenu.phoneNumber.name, image: phoneSymbol),
      Item(title: AuthMenu.anonymous.name, image: anonSymbol),
      Item(title: AuthMenu.custom.name, image: shieldSymbol),
    ]
    let header = "Other Authentication Methods"
    return Section(headerDescription: header, items: otherOptions)
  }

  static var recaptchaSection: Section {
    let image = UIImage(named: "firebaseIcon")
    let header = "Initialize reCAPTCHA Enterprise"
    let item = Item(title: AuthMenu.initRecaptcha.name, hasNestedContent: false, image: image)
    return Section(headerDescription: header, items: [item])
  }

  static var customAuthDomainSection: Section {
    let image = UIImage(named: "firebaseIcon")
    let header = "Custom Auth Domain"
    let item = Item(title: AuthMenu.customAuthDomain.name, hasNestedContent: false, image: image)
    return Section(headerDescription: header, items: [item])
  }

  static var appSection: Section {
    let header = "APP"
    let items: [Item] = [
      Item(title: AuthMenu.getToken.name),
      Item(title: AuthMenu.getTokenForceRefresh.name),
      Item(title: AuthMenu.addAuthStateChangeListener.name),
      Item(title: AuthMenu.removeLastAuthStateChangeListener.name),
      Item(title: AuthMenu.addIdTokenChangeListener.name),
      Item(title: AuthMenu.removeLastIdTokenChangeListener.name),
      Item(title: AuthMenu.verifyClient.name),
      Item(title: AuthMenu.deleteApp.name),
    ]
    return Section(headerDescription: header, items: items)
  }

  static var oobSection: Section {
    let header = "OOB"
    let items: [Item] = [
      Item(title: AuthMenu.actionType.name, detailTitle: ActionCodeRequestType.inApp.name),
      Item(title: AuthMenu.continueURL.name, detailTitle: "--", isEditable: true),
      Item(title: AuthMenu.requestVerifyEmail.name),
      Item(title: AuthMenu.requestPasswordReset.name),
      Item(title: AuthMenu.resetPassword.name),
      Item(title: AuthMenu.checkActionCode.name),
      Item(title: AuthMenu.applyActionCode.name),
      Item(title: AuthMenu.verifyPasswordResetCode.name),
    ]
    return Section(headerDescription: header, items: items)
  }

  static var multifactorSection: Section {
    let header = "Multi Factor"
    let items: [Item] = [
      Item(title: AuthMenu.phoneEnroll.name),
      Item(title: AuthMenu.totpEnroll.name),
      Item(title: AuthMenu.multifactorUnenroll.name),
    ]
    return Section(headerDescription: header, items: items)
  }

  static let sections: [Section] =
    [settingsSection, providerSection, emailPasswordSection, otherSection, recaptchaSection,
     customAuthDomainSection, appSection, oobSection, multifactorSection]

  static var authLinkSections: [Section] {
    let allItems = [providerSection, emailPasswordSection, otherSection].flatMap { $0.items }
    let header = "Manage linking between providers"
    let footer =
      "Select an unchecked row to link the currently signed in user to that auth provider. To unlink the user from a linked provider, select its corresponding row marked with a checkmark."
    return [Section(headerDescription: header, footerDescription: footer, items: allItems)]
  }

  var sections: [Section] = AuthMenuData.sections
}
