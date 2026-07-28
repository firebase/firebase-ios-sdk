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

/// Configuration for the generative AI backend API used by this SDK.
struct APIConfig: Sendable, Hashable, Encodable {
  /// The service to use for generative AI.
  ///
  /// This controls which backend API is used by the SDK.
  let service: Service

  /// The version of the selected API to use, e.g., "v1".
  let version: Version

  /// Initializes an API configuration.
  ///
  /// - Parameters:
  ///   - service: The API service to use for generative AI.
  ///   - version: The version of the API to use.
  init(service: Service, version: Version) {
    self.service = service
    self.version = version
  }
}

extension APIConfig {
  /// API services providing generative AI functionality.
  ///
  /// See [Agent Platform Gemini API and Gemini Developer API
  /// differences](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/migrate/migrate-google-ai#google-ai)
  /// for a comparison of the two [API services](https://google.aip.dev/9#api-service).
  enum Service: Hashable, Encodable {
    /// Agent Platform Gemini API.
    ///
    /// See the [Cloud
    /// docs](https://docs.cloud.google.com/gemini-enterprise-agent-platform/reference/models/inference) for
    /// more details.
    case agentPlatform(endpoint: Endpoint, location: String)

    /// The Gemini Developer API provided by Google AI.
    ///
    /// See the [Google AI docs](https://ai.google.dev/gemini-api/docs) for more details.
    case googleAI(endpoint: Endpoint)

    /// The specific network address to use for API requests.
    ///
    /// This must correspond with the API set in `service`.
    var endpoint: Endpoint {
      switch self {
      case let .agentPlatform(endpoint: endpoint, _):
        return endpoint
      case let .googleAI(endpoint: endpoint):
        return endpoint
      }
    }
  }
}

extension APIConfig.Service {
  /// Network addresses for generative AI API services.
  // TODO: maybe remove the https:// prefix and just add it as needed? websockets use these too.
  enum Endpoint: String, Encodable {
    /// The Firebase proxy production endpoint.
    ///
    /// This endpoint supports both the Gemini Developer API and the Agent Platform Gemini API.
    case firebaseProxyProd = "https://firebasevertexai.googleapis.com"

    #if DEBUG
      /// The Firebase proxy staging endpoint; for SDK development and testing only.
      ///
      /// This endpoint supports both the Gemini Developer API (commonly referred to as Google AI)
      /// and the Agent Platform Gemini API.
      case firebaseProxyStaging = "https://staging-firebasevertexai.sandbox.googleapis.com"

      /// The Gemini Developer API (Google AI) direct production endpoint; for SDK development and
      /// testing only.
      ///
      /// This bypasses the Firebase proxy and directly connects to the Gemini Developer API
      /// (Google AI) backend. This endpoint only supports the Gemini Developer API, not the
      /// Agent Platform Gemini API.
      case googleAIBypassProxy = "https://generativelanguage.googleapis.com"

      /// The Agent Platform Gemini API direct staging endpoint; for SDK development and
      /// testing only.
      ///
      /// This bypasses the Firebase proxy and directly connects to the Agent Platform Gemini API
      /// backend. This endpoint only supports the Agent Platform Gemini API, not the Gemini
      /// Developer API.
      case agentPlatformStagingBypassProxy = "https://staging-aiplatform.sandbox.googleapis.com"
    #endif // DEBUG
  }
}

extension APIConfig {
  /// Versions of the configured API service (`APIConfig.Service`).
  enum Version: String, Encodable {
    /// The beta channel for version 1 of the API.
    case v1beta

    #if DEBUG
      /// The stable channel for version 1 of the API; currently for SDK development and testing
      /// only.
      case v1

      /// The beta channel for version 1 of the direct Agent Platform Gemini API, when
      /// bypassing the Firebase proxy; for SDK development and testing only.
      case v1beta1
    #endif // DEBUG
  }
}
