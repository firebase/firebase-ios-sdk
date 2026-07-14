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
  /// The generic reusable api auth config. Deprecated. Please use AuthConfig (google/cloud/aiplatform/master/auth.proto) instead.
  public struct ApiAuth: Codable, Sendable, Equatable, Hashable {
    /// The API secret.
    public var apiKeyConfig: ApiAuthApiKeyConfig?
    
    /// Creates a new `ApiAuth`.
    public init(
      apiKeyConfig: ApiAuthApiKeyConfig? = nil
    ) {
      self.apiKeyConfig = apiKeyConfig
    }
    enum CodingKeys: String, CodingKey {
      case apiKeyConfig = "apiKeyConfig"
    }
  }
}