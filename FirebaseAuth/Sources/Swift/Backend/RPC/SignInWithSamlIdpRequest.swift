// Copyright 2025 Google LLC
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

final class SignInWithSamlIdpRequest: AuthRPCRequest {
  typealias Response = SignInWithSamlIdpResponse
  private let config: AuthRequestConfiguration
  private let requestUri: String
  private let postBody: String
  private let returnSecureToken: Bool

  init(requestUri: String,
       postBody: String,
       returnSecureToken: Bool,
       requestConfiguration: AuthRequestConfiguration) {
    self.requestUri = requestUri
    self.postBody = postBody
    self.returnSecureToken = returnSecureToken
    config = requestConfiguration
  }

  func requestConfiguration() -> AuthRequestConfiguration {
    return config
  }

  func requestURL() -> URL {
    var comps = URLComponents()
    comps.scheme = "https"
    comps.host = "identitytoolkit.googleapis.com"
    comps.path = "/v1/accounts:signInWithIdp"
    comps.queryItems = [URLQueryItem(name: "key", value: config.apiKey)]
    return comps.url!
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    var body: [String: AnyHashable] = [
      "requestUri": requestUri,
      "postBody": postBody,
      "returnSecureToken": returnSecureToken,
    ]
    return body
  }
}
