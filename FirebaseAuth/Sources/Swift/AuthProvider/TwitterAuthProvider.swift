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

/**
   @brief Utility class for constructing Twitter Sign In credentials.
*/
@objc(FIRTwitterAuthProvider) open class TwitterAuthProvider: NSObject {

  @objc static public let id = "twitter.com"

  /**
     @brief Creates an `AuthCredential` for a Twitter sign in.

     @param token The Twitter OAuth token.
     @param secret The Twitter OAuth secret.
     @return An AuthCredential containing the Twitter credentials.
  */
  @objc public class func credential(withToken token:String, secret: String) -> AuthCredential {
    return TwitterAuthCredential(withToken: token, secret: secret)
  }
}

@objc(FIRTwitterAuthCredential) fileprivate class TwitterAuthCredential: AuthCredential, NSSecureCoding {
  private let token: String
  private let secret: String

  init(withToken token:String, secret: String) {
    self.token = token
    self.secret = secret
    super.init(provider: TwitterAuthProvider.id)
  }

  func prepareVerifyAssertionRequest(request: FIRVerifyAssertionRequest) {
    request.providerAccessToken = token
    request.providerOAuthTokenSecret = secret
  }

  static var supportsSecureCoding = true

  func encode(with coder: NSCoder) {
    coder.encode(token)
    coder.encode(secret)
  }

  required init?(coder: NSCoder) {
    guard let token = coder.decodeObject(forKey: "token") as? String,
          let secret = coder.decodeObject(forKey: "secret") as? String else {
      return nil
    }
    self.token = token
    self.secret = secret
    super.init(provider: TwitterAuthProvider.id)
  }
}
