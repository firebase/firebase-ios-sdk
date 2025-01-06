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

/// Utility class for constructing GitHub Sign In credentials.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRGitHubAuthProvider) open class GitHubAuthProvider: NSObject {
  /// A string constant identifying the GitHub identity provider.
  @objc public static let id = "github.com"

  /// Creates an `AuthCredential` for a GitHub sign in.
  /// - Parameter token: The GitHub OAuth access token.
  /// - Returns: An AuthCredential containing the GitHub credentials.
  @objc open class func credential(withToken token: String) -> AuthCredential {
    return GitHubAuthCredential(withToken: token)
  }

  @available(*, unavailable)
  @objc override public init() {
    fatalError("This class is not meant to be initialized.")
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRGitHubAuthCredential) class GitHubAuthCredential: AuthCredential, NSSecureCoding,
  @unchecked Sendable {
  let token: String?

  init(withToken token: String) {
    self.token = token
    super.init(provider: GitHubAuthProvider.id)
  }

  override func prepare(_ request: VerifyAssertionRequest) {
    request.providerAccessToken = token
  }

  // MARK: Secure Coding

  public static let supportsSecureCoding = true

  func encode(with coder: NSCoder) {
    coder.encode(token, forKey: "token")
  }

  required init?(coder: NSCoder) {
    token = coder.decodeObject(of: NSString.self, forKey: "token") as String?
    super.init(provider: GitHubAuthProvider.id)
  }
}
