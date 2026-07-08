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

/// Represents available backend APIs for the Firebase AI SDK.
public struct Backend {
  // MARK: - Public API

  /// Initializes a `Backend` configured for the Gemini API in Vertex AI.
  ///
  /// Defaults to the location `us-central1`; see
  /// [Vertex AI locations](https://firebase.google.com/docs/vertex-ai/locations?platform=ios#available-locations)
  /// for a list of supported locations.
  @available(*, deprecated, message: """
  Use agentPlatform(location:) instead; note that the default location is now "global" instead of "us-central1"
  """)
  public static func vertexAI() -> Backend {
    return Backend(
      apiConfig: APIConfig(
        service: .agentPlatform(endpoint: .firebaseProxyProd, location: "us-central1"),
        version: .v1beta
      )
    )
  }

  /// Initializes a `Backend` configured for the Gemini API in Vertex AI.
  ///
  /// - Parameters:
  ///   - location: The region identifier; see
  ///     [Vertex AI locations](https://firebase.google.com/docs/vertex-ai/locations?platform=ios#available-locations)
  ///     for a list of supported locations.
  @available(*, deprecated, renamed: "agentPlatform(location:)", message: """
  Vertex AI has been renamed to the Gemini Enterprise Agent Platform.
  """)
  public static func vertexAI(location: String) -> Backend {
    return Backend(
      apiConfig: APIConfig(
        service: .agentPlatform(endpoint: .firebaseProxyProd, location: location),
        version: .v1beta
      )
    )
  }

  /// Initializes a `Backend` configured for the Gemini Enterprise Agent Platform.
  ///
  /// > Note: The Gemini Enterprise Agent Platform was formerly known as the Vertex AI.
  ///
  /// - Parameters:
  ///   - location: The region identifier, defaulting to `global`; see
  ///     [Vertex AI locations](https://firebase.google.com/docs/vertex-ai/locations?platform=ios#available-locations)
  ///     for a list of supported locations.
  public static func agentPlatform(location: String = "global") -> Backend {
    return Backend(
      apiConfig: APIConfig(
        service: .agentPlatform(endpoint: .firebaseProxyProd, location: location),
        version: .v1beta
      )
    )
  }

  /// Initializes a `Backend` configured for the Google Developer API.
  public static func googleAI() -> Backend {
    return Backend(
      apiConfig: APIConfig(
        service: .googleAI(endpoint: .firebaseProxyProd),
        version: .v1beta
      )
    )
  }

  // MARK: - Internal

  let apiConfig: APIConfig

  init(apiConfig: APIConfig) {
    self.apiConfig = apiConfig
  }
}
