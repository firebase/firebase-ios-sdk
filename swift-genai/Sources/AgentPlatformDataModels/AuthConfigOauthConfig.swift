// Copyright 2026 Google LLC
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


extension AgentPlatform {
  /// Config for user oauth.
  package struct AuthConfigOauthConfig: Codable, Sendable, Equatable, Hashable {
    /// Access token for extension endpoint. Only used to propagate token from [[ExecuteExtensionRequest.runtime_auth_config]] at request time.
    package var accessToken: String?
    
    /// The service account used to generate access tokens for executing the Extension. - If the service account is specified, the `iam.serviceAccounts.getAccessToken` permission should be granted to Vertex AI Extension Service Agent (https://cloud.google.com/vertex-ai/docs/general/access-control#service-agents) on the provided service account.
    package var serviceAccount: String?
    
    /// Creates a new `AuthConfigOauthConfig`.
    package init(
      accessToken: String? = nil,
      serviceAccount: String? = nil
    ) {
      self.accessToken = accessToken
      self.serviceAccount = serviceAccount
    }
    enum CodingKeys: String, CodingKey {
      case accessToken = "accessToken"
      case serviceAccount = "serviceAccount"
    }
  }
}