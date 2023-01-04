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
   @brief Utility class for constructing Facebook Sign In credentials.
*/
@objc(FIRFacebookAuthProvider) open class FacebookAuthProvider: NSObject {

  @objc static public let id = "facebook.com"

  /**
     @brief Creates an `AuthCredential` for a Facebook sign in.

     @param accessToken The Access Token from Facebook.
     @return An AuthCredential containing the Facebook credentials.
  */
  @objc public class func credential(withAccessToken accessToken:String) -> AuthCredential {
    return FacebookAuthCredential(withAccessToken: accessToken)
  }
}

@objc(FIRFacebookAuthCredential) fileprivate class FacebookAuthCredential: AuthCredential, NSSecureCoding {
  private let accessToken: String

  init(withAccessToken accessToken:String) {
    self.accessToken = accessToken
    super.init(provider: FacebookAuthProvider.id)
  }

  func prepareVerifyAssertionRequest(request: FIRVerifyAssertionRequest) {
    request.providerAccessToken = accessToken
  }

  static var supportsSecureCoding = true

  func encode(with coder: NSCoder) {
    coder.encode(accessToken)
  }

  required init?(coder: NSCoder) {
    guard let accessToken = coder.decodeObject(forKey: "accessToken") as? String else {
      return nil
    }
    self.accessToken = accessToken
    super.init(provider: FacebookAuthProvider.id)
  }
}
