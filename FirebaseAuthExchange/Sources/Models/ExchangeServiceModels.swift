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

import Foundation

// MARK: - Request Models

/// Request for exchanging a Firebase Installations token for an Auth Exchange access token.
struct ExchangeInstallationAuthTokenRequest: Encodable {
  /// A Firebase Installations auth token as a base64-encoded JWT.
  let installationAuthToken: String
}

/// Request for exchanging a custom auth token for an Auth Exchange access token.
struct ExchangeCustomTokenRequest: Encodable {
  /// A custom base64-encoded JWT signed with the developer's credentials.
  let customToken: String
}

/// Request for exchanging an OpenID Connect (OIDC) token for an Auth Exchange access token.
struct ExchangeOIDCTokenRequest: Encodable {
  /// The display name or identifier of the OIDC provider.
  let providerID: String

  struct ImplicitCredentials: Encodable {
    let idToken: String
  }

  struct AuthCodeCredentials: Encodable {
    let sessionID: String

    let credentialURI: String
  }

  // TODO(andrewheard): Investigate using an enum for credentials to represent oneof semantics.
  let implicitCredentials: ImplicitCredentials?

  let authCodeCredentials: AuthCodeCredentials?

  init(providerID: String, implicitCredentials: ImplicitCredentials) {
    self.providerID = providerID
    self.implicitCredentials = implicitCredentials
    authCodeCredentials = nil
  }

  init(providerID: String, authCodeCredentials: AuthCodeCredentials) {
    self.providerID = providerID
    implicitCredentials = nil
    self.authCodeCredentials = authCodeCredentials
  }
}
