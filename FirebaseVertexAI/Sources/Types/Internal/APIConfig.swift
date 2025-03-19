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

/// Configuration for the generative AI backend API used by this SDK.
struct APIConfig: Sendable, Hashable {
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
  enum Service: Hashable {
    /// The Gemini Enterprise API provided by Vertex AI.
    ///
    /// See the [Cloud
    /// docs](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference) for
    /// more details.
    case vertexAI

    /// The Gemini Developer API provided by Google AI.
    ///
    /// See the [Google AI docs](https://ai.google.dev/gemini-api/docs) for more details.
    case developer(endpoint: Endpoint)

    /// The specific network address to use for API requests.
    ///
    /// This must correspond with the API set in `service`.
    var endpoint: Endpoint {
      switch self {
      case .vertexAI:
        return .firebaseVertexAIProd
      case let .developer(endpoint: endpoint):
        return endpoint
      }
    }
  }
}

extension APIConfig.Service {
  /// Network addresses for generative AI API services.
  enum Endpoint: String {
    /// The Vertex AI in Firebase production endpoint.
    case firebaseVertexAIProd = "https://firebasevertexai.googleapis.com"

    /// The Vertex AI in Firebase staging endpoint; for SDK development and testing only.
    case firebaseVertexAIStaging = "https://staging-firebasevertexai.sandbox.googleapis.com"

    /// The Gemini Developer API production endpoint; for SDK development and testing only.
    case generativeLanguage = "https://generativelanguage.googleapis.com"
  }
}

extension APIConfig {
  /// Versions of the configured API service (`APIConfig.Service`).
  enum Version: String {
    /// The stable channel for version 1 of the API.
    case v1

    /// The beta channel for version 1 of the API.
    case v1beta
  }
}

// MARK: - Coding Utilities

extension CodingUserInfoKey {
  static let apiConfig = {
    let keyName = "com.google.firebase.VertexAI.APIConfig"
    guard let userInfoKey = CodingUserInfoKey(rawValue: keyName) else {
      fatalError("The key name '\(keyName)' is not a valid raw value for CodingUserInfoKey.")
    }
    return userInfoKey
  }()
}

extension APIConfig {
  static func from(userInfo: [CodingUserInfoKey: Any]) -> APIConfig {
    guard let config = userInfo[CodingUserInfoKey.apiConfig] else {
      fatalError(
        "No value provided for '\(CodingUserInfoKey.apiConfig)' in the coder's userInfo."
      )
    }
    guard let config = config as? APIConfig else {
      fatalError("""
      The value provided for '\(CodingUserInfoKey.apiConfig)' in the coder's userInfo is not of \
      type '\(APIConfig.self)'; found type '\(config)'.
      """)
    }
    return config
  }
}

extension Decoder {
  var apiConfig: APIConfig { APIConfig.from(userInfo: userInfo) }
}

extension JSONDecoder {
  convenience init(apiConfig: APIConfig) {
    self.init()
    userInfo[CodingUserInfoKey.apiConfig] = apiConfig
  }
}

extension Encoder {
  var apiConfig: APIConfig { APIConfig.from(userInfo: userInfo) }
}

extension JSONEncoder {
  convenience init(apiConfig: APIConfig) {
    self.init()
    userInfo[CodingUserInfoKey.apiConfig] = apiConfig
  }
}
