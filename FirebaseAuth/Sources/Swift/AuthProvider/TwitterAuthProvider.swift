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

/// Utility class for constructing Twitter Sign In credentials.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRTwitterAuthProvider) open class TwitterAuthProvider: NSObject {
  /// A string constant identifying the Twitter identity provider.
  @objc public static let id = "twitter.com"

  /// Creates an `AuthCredential` for a Twitter sign in.
  /// - Parameter token: The Twitter OAuth token.
  /// - Parameter secret: The Twitter OAuth secret.
  /// - Returns: An AuthCredential containing the Twitter credentials.
  @objc open class func credential(withToken token: String, secret: String) -> AuthCredential {
    return TwitterAuthCredential(withToken: token, secret: secret)
  }

  @available(*, unavailable)
  @objc override public init() {
    fatalError("This class is not meant to be initialized.")
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRTwitterAuthCredential) class TwitterAuthCredential: AuthCredential, NSSecureCoding {
  let token: String
  let secret: String

  init(withToken token: String, secret: String) {
    self.token = token
    self.secret = secret
    super.init(provider: TwitterAuthProvider.id)
  }

  override func prepare(_ request: VerifyAssertionRequest) {
    request.providerAccessToken = token
    request.providerOAuthTokenSecret = secret
  }

  // MARK: Secure Coding

  static var supportsSecureCoding = true

  func encode(with coder: NSCoder) {
    coder.encode(token, forKey: "token")
    coder.encode(secret, forKey: "secret")
  }

  required init?(coder: NSCoder) {
    guard let token = coder.decodeObject(of: NSString.self, forKey: "token") as? String,
          let secret = coder.decodeObject(of: NSString.self, forKey: "secret") as? String else {
      return nil
    }
    self.token = token
    self.secret = secret
    super.init(provider: TwitterAuthProvider.id)
  }
}
