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
class VerifyClientRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = VerifyClientResponse

  /// The endpoint for the verifyClient request.
  private static let verifyClientEndpoint = "verifyClient"

  /// The key for the appToken request parameter.
  private static let appTokenKey = "appToken"

  /// The key for the isSandbox request parameter.
  private static let isSandboxKey = "isSandbox"

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var postBody = [String: AnyHashable]()
    if let appToken = appToken {
      postBody[Self.appTokenKey] = appToken
    }
    if isSandbox {
      postBody[Self.isSandboxKey] = true
    }
    return postBody
  }

  /// The APNS device token.
  private(set) var appToken: String?

  /// The flag that denotes if the appToken  pertains to Sandbox or Production.
  private(set) var isSandbox: Bool

  init(withAppToken appToken: String?,
       isSandbox: Bool,
       requestConfiguration: AuthRequestConfiguration) {
    self.appToken = appToken
    self.isSandbox = isSandbox
    super.init(endpoint: Self.verifyClientEndpoint, requestConfiguration: requestConfiguration)
  }
}
