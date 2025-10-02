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
  /// See [Vertex AI and Google AI
  /// differences](https://cloud.google.com/vertex-ai/generative-ai/docs/overview#how-gemini-vertex-different-gemini-aistudio)
  /// for a comparison of the two [API services](https://google.aip.dev/9#api-service).
  enum Service: Hashable, Encodable {
    /// Vertex AI Gemini API.
    ///
    /// See the [Cloud
    /// docs](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference) for
    /// more details.
    case vertexAI(endpoint: Endpoint, location: String)

    /// The Gemini Developer API provided by Google AI.
    ///
    /// See the [Google AI docs](https://ai.google.dev/gemini-api/docs) for more details.
    case googleAI(endpoint: Endpoint)

    /// The specific network address to use for API requests.
    ///
    /// This must correspond with the API set in `service`.
    var endpoint: Endpoint {
      switch self {
      case let .vertexAI(endpoint: endpoint, _):
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
    /// This endpoint supports both Google AI and Vertex AI.
    case firebaseProxyProd = "https://firebasevertexai.googleapis.com"

    /// The Firebase proxy staging endpoint; for SDK development and testing only.
    ///
    /// This endpoint supports both the Gemini Developer API (commonly referred to as Google AI)
    /// and the Gemini API in Vertex AI (commonly referred to simply as Vertex AI).
    case firebaseProxyStaging = "https://staging-firebasevertexai.sandbox.googleapis.com"

    /// The Gemini Developer API (Google AI) direct production endpoint; for SDK development and
    /// testing only.
    ///
    /// This bypasses the Firebase proxy and directly connects to the Gemini Developer API
    /// (Google AI) backend. This endpoint only supports the Gemini Developer API, not Vertex AI.
    case googleAIBypassProxy = "https://generativelanguage.googleapis.com"
  }
}

extension APIConfig {
  /// Versions of the configured API service (`APIConfig.Service`).
  enum Version: String, Encodable {
    /// The stable channel for version 1 of the API.
    case v1

    /// The beta channel for version 1 of the API.
    case v1beta
  }
}
