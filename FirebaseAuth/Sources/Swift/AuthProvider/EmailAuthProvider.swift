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

/// A concrete implementation of `AuthProvider` for Email & Password Sign In.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIREmailAuthProvider) open class EmailAuthProvider: NSObject {
  /// A string constant identifying the email & password identity provider.
  @objc public static let id = "password"

  /// Creates an `AuthCredential` for an email & password sign in
  /// - Parameter email: The user's email address.
  /// - Parameter password: The user's password.
  /// - Returns: An `AuthCredential` containing the email & password credential.
  @objc open class func credential(withEmail email: String, password: String) -> AuthCredential {
    return EmailAuthCredential(withEmail: email, password: password)
  }

  /// Creates an `AuthCredential` for an email & link sign in.
  /// - Parameter email: The user's email address.
  /// - Parameter link: The email sign-in link.
  /// - Returns: An `AuthCredential` containing the email & link credential.
  @objc open class func credential(withEmail email: String, link: String) -> AuthCredential {
    return EmailAuthCredential(withEmail: email, link: link)
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIREmailPasswordAuthCredential) class EmailAuthCredential: AuthCredential, NSSecureCoding {
  let email: String

  enum EmailType {
    case password(String)
    case link(String)
  }

  let emailType: EmailType

  init(withEmail email: String, password: String) {
    self.email = email
    emailType = .password(password)
    super.init(provider: EmailAuthProvider.id)
  }

  init(withEmail email: String, link: String) {
    self.email = email
    emailType = .link(link)
    super.init(provider: EmailAuthProvider.id)
  }

  // MARK: Secure Coding

  static let supportsSecureCoding = true

  func encode(with coder: NSCoder) {
    coder.encode(email, forKey: "email")
    switch emailType {
    case let .password(password): coder.encode(password, forKey: "password")
    case let .link(link): coder.encode(link, forKey: "link")
    }
  }

  required init?(coder: NSCoder) {
    guard let email = coder.decodeObject(of: NSString.self, forKey: "email") as? String else {
      return nil
    }
    self.email = email
    if let password = coder.decodeObject(of: NSString.self, forKey: "password") as? String {
      emailType = .password(password)
    } else if let link = coder.decodeObject(of: NSString.self, forKey: "link") as? String {
      emailType = .link(link)
    } else {
      return nil
    }
    super.init(provider: EmailAuthProvider.id)
  }
}
