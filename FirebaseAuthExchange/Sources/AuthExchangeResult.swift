// Copyright 2022 Google LLC
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

/** A class that wraps around the Auth Exchange response from the backend. This will always contain the `AuthExchangeToken`. For some provider flows (i.e. OIDC), a provider ID token and/or a provider refresh token may also be returned. */
@objc(FIRAuthExchangeResult) public class AuthExchangeResult: NSObject {
  @objc public init(authExchangeToken: AuthExchangeToken, providerIDToken: String?, providerRefreshToken: String?) {
    self.authExchangeToken = authExchangeToken
    self.providerIDToken = providerIDToken
    self.providerRefreshToken = providerRefreshToken
  }

  @objc public init(authExchangeToken: AuthExchangeToken) {
    self.authExchangeToken = authExchangeToken
    self.providerIDToken = nil
    self.providerRefreshToken = nil
  }

  @objc public let authExchangeToken: AuthExchangeToken

  @objc public let providerIDToken: String?

  @objc public let providerRefreshToken: String?
}
