// Copyright 2022 Email LLC
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

/**
   @brief A concrete implementation of `AuthProvider` for Email & Password Sign In.
*/
@objc(FIREmailAuthProvider) open class EmailAuthProvider: NSObject {

  @objc static public let id = "password"

  /**
      @brief Creates an `AuthCredential` for an email & password sign in.

      @param email The user's email address.
      @param password The user's password.
      @return An `AuthCredential` containing the email & password credential.
   */
  @objc public class func credential(withEmail email:String, password: String) -> AuthCredential {
    return EmailAuthCredential(withEmail: email, password: password)
  }

  /** @fn credentialWithEmail:Link:
      @brief Creates an `AuthCredential` for an email & link sign in.

      @param email The user's email address.
      @param link The email sign-in link.
      @return An `AuthCredential` containing the email & link credential.
   */
  @objc public class func credential(withEmail email:String, link: String) -> AuthCredential {
    return EmailAuthCredential(withEmail: email, link: link)
  }
}

// TODO: Change all visibilities to internal and remove objc, once internal dependents are converted.
@objc(FIREmailPasswordAuthCredential) public class EmailAuthCredential: AuthCredential, NSSecureCoding {
  @objc public let email: String
  @objc public let password: String?
  @objc public let link: String?

  @objc public init(withEmail email: String, password: String) {
    self.email = email
    self.password = password
    self.link = nil
    super.init(provider: EmailAuthProvider.id)
  }

  @objc public init(withEmail email: String, link: String) {
    self.email = email
    self.link = link
    self.password = nil
    super.init(provider: EmailAuthProvider.id)
  }

  public static var supportsSecureCoding = true

  public func encode(with coder: NSCoder) {
    coder.encode(email)
    coder.encode(password)
    coder.encode(link)
  }

  public required init?(coder: NSCoder) {
    guard let email = coder.decodeObject(forKey: "email") as? String else {
      return nil
    }
    self.email = email
    if let password = coder.decodeObject(forKey: "password") as? String {
      self.password = password
      self.link = nil
    } else if let link = coder.decodeObject(forKey: "link") as? String {
      self.link = link
      self.password = nil
    } else {
      return nil
    }
    super.init(provider: EmailAuthProvider.id)
  }
}
