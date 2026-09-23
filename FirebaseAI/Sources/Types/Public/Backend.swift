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
  /// [available
  /// locations](https://firebase.google.com/docs/ai-logic/locations?api=vertex#available-locations)
  /// for a list of supported locations.
  @available(*, deprecated, message: """
  Use enterprise(location:) instead; note that the default location is now "global" instead of "us-central1"
  """)
  public static func vertexAI() -> Backend {
    return enterprise(location: "us-central1")
  }

  /// Initializes a `Backend` configured for the Gemini API in Vertex AI.
  ///
  /// - Parameters:
  ///   - location: The region identifier; see [available locations][1]
  ///     for a list of supported locations.
  ///
  /// [1]: https://firebase.google.com/docs/ai-logic/locations?api=vertex#available-locations
  @available(*, deprecated, renamed: "enterprise(location:)", message: """
  Vertex AI has been renamed to the Gemini Enterprise API.
  """)
  public static func vertexAI(location: String) -> Backend {
    return enterprise(location: location)
  }

  /// Initializes a `Backend` configured for the Gemini Enterprise API.
  ///
  /// > Note: The Gemini Enterprise API was formerly known as Vertex AI and, briefly,
  /// > the Agent Platform Gemini API.
  ///
  /// - Parameters:
  ///   - location: The region identifier, defaulting to `global`; see
  ///     [available locations][1] for a list of supported locations.
  ///
  /// [1]: https://firebase.google.com/docs/ai-logic/locations?api=vertex#available-locations
  public static func enterprise(location: String = "global") -> Backend {
    return Backend(
      apiConfig: APIConfig(
        service: .enterprise(endpoint: .firebaseProxyProd, location: location),
        version: .v1beta
      )
    )
  }

  /// Initializes a `Backend` configured for the Gemini Enterprise API.
  ///
  /// - Parameters:
  ///   - location: The region identifier, defaulting to `global`; see
  ///     [available locations][1] for a list of supported locations.
  ///
  /// [1]: https://firebase.google.com/docs/ai-logic/locations?api=vertex#available-locations
  @available(*, deprecated, renamed: "enterprise(location:)", message: """
  The Agent Platform Gemini API has been renamed to the Gemini Enterprise API.
  """)
  public static func agentPlatform(location: String = "global") -> Backend {
    return enterprise(location: location)
  }

  /// Initializes a `Backend` configured for the Gemini Developer API.
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
