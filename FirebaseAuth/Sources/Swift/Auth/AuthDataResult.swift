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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
extension AuthDataResult: NSSecureCoding {}

/// Helper object that contains the result of a successful sign-in, link and reauthenticate
/// action.
///
/// It contains references to a `User` instance and an `AdditionalUserInfo` instance.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRAuthDataResult) open class AuthDataResult: NSObject {
  /// The signed in user.
  @objc public let user: User

  /// If available, contains the additional IdP specific information about signed in user.
  @objc public let additionalUserInfo: AdditionalUserInfo?

  /// This property will be non-nil after a successful headful-lite sign-in via
  /// `signIn(with:uiDelegate:completion:)`.
  ///
  /// May be used to obtain the accessToken and/or IDToken
  /// pertaining to a recently signed-in user.
  @objc public let credential: OAuthCredential?

  /// Designated initializer.
  /// - Parameter user: The signed in user reference.
  /// - Parameter additionalUserInfo: The additional user info.
  /// - Parameter credential: The updated OAuth credential if available.
  init(withUser user: User,
       additionalUserInfo: AdditionalUserInfo?,
       credential: OAuthCredential? = nil) {
    self.user = user
    self.additionalUserInfo = additionalUserInfo
    self.credential = credential
  }

  // MARK: Secure Coding

  private let kAdditionalUserInfoCodingKey = "additionalUserInfo"
  private let kUserCodingKey = "user"
  private let kCredentialCodingKey = "credential"

  public static var supportsSecureCoding = true

  public func encode(with coder: NSCoder) {
    coder.encode(user, forKey: kUserCodingKey)
    coder.encode(additionalUserInfo, forKey: kAdditionalUserInfoCodingKey)
    coder.encode(credential, forKey: kCredentialCodingKey)
  }

  public required init?(coder: NSCoder) {
    guard let user = coder.decodeObject(of: User.self, forKey: kUserCodingKey) else {
      return nil
    }
    self.user = user
    additionalUserInfo = coder.decodeObject(of: AdditionalUserInfo.self,
                                            forKey: kAdditionalUserInfoCodingKey)
    credential = coder.decodeObject(of: OAuthCredential.self, forKey: kCredentialCodingKey)
  }
}
