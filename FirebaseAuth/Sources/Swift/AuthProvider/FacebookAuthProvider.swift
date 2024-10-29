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

/// Utility class for constructing Facebook Sign In credentials.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRFacebookAuthProvider) open class FacebookAuthProvider: NSObject {
  /// A string constant identifying the Facebook identity provider.
  @objc public static let id = "facebook.com"

  /// Creates an `AuthCredential` for a Facebook sign in.
  /// - Parameter accessToken: The Access Token from Facebook.
  /// - Returns: An `AuthCredential` containing the Facebook credentials.
  @objc open class func credential(withAccessToken accessToken: String) -> AuthCredential {
    return FacebookAuthCredential(withAccessToken: accessToken)
  }

  @available(*, unavailable)
  @objc override public init() {
    fatalError("This class is not meant to be initialized.")
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRFacebookAuthCredential) class FacebookAuthCredential: AuthCredential, NSSecureCoding {
  let accessToken: String

  init(withAccessToken accessToken: String) {
    self.accessToken = accessToken
    super.init(provider: FacebookAuthProvider.id)
  }

  override func prepare(_ request: VerifyAssertionRequest) {
    request.providerAccessToken = accessToken
  }

  // MARK: Secure Coding

  static let supportsSecureCoding = true

  func encode(with coder: NSCoder) {
    coder.encode(accessToken, forKey: "accessToken")
  }

  required init?(coder: NSCoder) {
    guard let accessToken = coder.decodeObject(of: NSString.self, forKey: "accessToken") as? String
    else {
      return nil
    }
    self.accessToken = accessToken
    super.init(provider: FacebookAuthProvider.id)
  }
}
