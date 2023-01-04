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
   @brief Utility class for constructing GitHub Sign In credentials.
*/
@objc(FIRGitHubAuthProvider) open class GitHubAuthProvider: NSObject {

  @objc static public let id = "github.com"

  /**
     @brief Creates an `AuthCredential` for a GitHub sign in.

     @param token The GitHub OAuth access token.
     @return An AuthCredential containing the GitHub credentials.
  */
  @objc public class func credential(withToken token:String) -> AuthCredential {
    return GitHubAuthCredential(withToken: token)
  }
}

@objc(FIRGitHubAuthCredential) fileprivate class GitHubAuthCredential: AuthCredential, NSSecureCoding {
  private let token: String

  init(withToken token:String) {
    self.token = token
    super.init(provider: GitHubAuthProvider.id)
  }

  func prepareVerifyAssertionRequest(request: FIRVerifyAssertionRequest) {
    request.providerAccessToken = token
  }

  static var supportsSecureCoding = true

  func encode(with coder: NSCoder) {
    coder.encode(token)
  }

  required init?(coder: NSCoder) {
    guard let token = coder.decodeObject(forKey: "token") as? String else {
      return nil
    }
    self.token = token
    super.init(provider: GitHubAuthProvider.id)
  }
}
