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
struct APIConfig: Sendable, Hashable {
  /// The service to use for generative AI.
  ///
  /// This controls which backend API is used by the SDK.
  let service: Service

  /// The specific network address to use for API requests.
  ///
  /// This must correspond with the API set in `service`.
  let serviceEndpoint: ServiceEndpoint

  /// The version of the selected API to use, e.g., "v1".
  let version: Version

  /// Initializes an API configuration.
  ///
  /// - Parameters:
  ///   - service: The API service to use for generative AI.
  ///   - serviceEndpoint: The network address to use for the API service.
  ///   - version: The version of the API to use.
  init(service: Service, serviceEndpoint: ServiceEndpoint, version: Version) {
    self.service = service
    self.serviceEndpoint = serviceEndpoint
    self.version = version
  }
}

extension APIConfig {
  /// API services providing generative AI functionality.
  ///
  /// See [Vertex AI and Google AI
  /// differences](https://cloud.google.com/vertex-ai/generative-ai/docs/overview#how-gemini-vertex-different-gemini-aistudio)
  /// for a comparison of the two [API services](https://google.aip.dev/9#api-service).
  enum Service {
    /// The Gemini Enterprise API provided by Vertex AI.
    ///
    /// See the [Cloud
    /// docs](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference) for
    /// more details.
    case vertexAI

    /// The Gemini Developer API provided by Google AI.
    ///
    /// See the [Google AI docs](https://ai.google.dev/gemini-api/docs) for more details.
    case developer
  }
}

extension APIConfig {
  /// Network addresses for generative AI API services.
  enum ServiceEndpoint: String {
    /// The Vertex AI in Firebase production endpoint.
    case firebaseVertexAIProd = "https://firebasevertexai.googleapis.com"

    /// The Vertex AI in Firebase staging endpoint; for SDK development and testing only.
    case firebaseVertexAIStaging = "https://staging-firebasevertexai.sandbox.googleapis.com"

    /// The Gemini Developer API production endpoint; for SDK development and testing only.
    case generativeLanguage = "https://generativelanguage.googleapis.com"
  }
}

extension APIConfig {
  /// Versions of the Vertex AI in Firebase server API.
  enum Version: String {
    /// The stable channel for version 1 of the API.
    case v1

    /// The beta channel for version 1 of the API.
    case v1beta
  }
}
