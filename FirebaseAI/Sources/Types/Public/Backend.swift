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
  /// - Parameters:
  ///   - location: The region identifier, defaulting to `us-central1`; see
  ///     [Vertex AI locations]
  ///     (https://firebase.google.com/docs/vertex-ai/locations?platform=ios#available-locations)
  ///     for a list of supported locations.
  public static func vertexAI(location: String = "us-central1") -> Backend {
    return Backend(
      apiConfig: APIConfig(
        service: .vertexAI(endpoint: .firebaseProxyProd, location: location),
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
