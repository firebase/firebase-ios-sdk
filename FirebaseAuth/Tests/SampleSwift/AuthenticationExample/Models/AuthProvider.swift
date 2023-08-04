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
enum AuthProvider: String {
  case google = "google.com"
  case apple = "apple.com"
  case twitter = "twitter.com"
  case microsoft = "microsoft.com"
  case gitHub = "github.com"
  case yahoo = "yahoo.com"
  case facebook = "facebook.com"
  case emailPassword = "password"
  case passwordless = "emailLink"
  case phoneNumber = "phone"
  case anonymous
  case custom

  /// More intuitively named getter for `rawValue`.
  var id: String { rawValue }

  /// The UI friendly name of the `AuthProvider`. Used for display.
  var name: String {
    switch self {
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
    case .facebook:
      return "Facebook"
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
    }
  }

  /// Failable initializer to create an `AuthProvider` from it's corresponding `name` value.
  /// - Parameter rawValue: String value representing `AuthProvider`'s name or type.
  init?(rawValue: String) {
    switch rawValue {
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
    case "Facebook":
      self = .facebook
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
    default: return nil
    }
  }
}

// MARK: DataSourceProvidable

extension AuthProvider: DataSourceProvidable {
  private static var providers: [AuthProvider] {
    [.google, .apple, .twitter, .microsoft, .gitHub, .yahoo, .facebook]
  }

  static var providerSection: Section {
    let providers = self.providers.map { Item(title: $0.name) }
    let header = "Identity Providers"
    let footer = "Choose a login flow from one of the identity providers above."
    return Section(headerDescription: header, footerDescription: footer, items: providers)
  }

  static var emailPasswordSection: Section {
    let image = UIImage(named: "firebaseIcon")
    let item = Item(title: emailPassword.name, hasNestedContent: true, image: image)
    let footer = "A example login flow with password authentication."
    return Section(footerDescription: footer, items: [item])
  }

  static var otherSection: Section {
    let lockSymbol = UIImage.systemImage("lock.slash.fill", tintColor: .systemOrange)
    let phoneSymbol = UIImage.systemImage("phone.fill", tintColor: .systemOrange)
    let anonSymbol = UIImage.systemImage("questionmark.circle.fill", tintColor: .systemOrange)
    let shieldSymbol = UIImage.systemImage("lock.shield.fill", tintColor: .systemOrange)

    let otherOptions = [
      Item(title: passwordless.name, image: lockSymbol),
      Item(title: phoneNumber.name, image: phoneSymbol),
      Item(title: anonymous.name, image: anonSymbol),
      Item(title: custom.name, image: shieldSymbol),
    ]
    return Section(footerDescription: "Other authentication methods.", items: otherOptions)
  }

  static var sections: [Section] {
    [providerSection, emailPasswordSection, otherSection]
  }

  static var authLinkSections: [Section] {
    let allItems = AuthProvider.sections.flatMap { $0.items }
    let header = "Manage linking between providers"
    let footer =
      "Select an unchecked row to link the currently signed in user to that auth provider. To unlink the user from a linked provider, select its corresponding row marked with a checkmark."
    return [Section(headerDescription: header, footerDescription: footer, items: allItems)]
  }

  var sections: [Section] { AuthProvider.sections }
}
