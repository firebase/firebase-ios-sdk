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
#if os(Linux)
  import FoundationNetworking
#endif

/// API backend to communicate with.
public enum Backend: Sendable {
  /// Use the [Vertex AI](https://cloud.google.com/vertex-ai/docs) backend.
  ///
  /// - Parameters:
  ///   - location: Geographic location for API requests to made to. For a list of supported
  /// locations, see the docs on
  ///     [Available
  /// locations](https://docs.cloud.google.com/vertex-ai/docs/general/locations#available-regions)\.
  ///     Note that models and feature endpoints may have additional location restrictions.
  ///   - publisher: The name of the model publisher to use for published models.
  ///   - projectId: The GCloud project ID to use for resource consumption. When using the Firebase
  /// authentication method,
  ///     you can retrieve the project ID via `FirebaseApp.options.projectID`.
  ///   - version: Version of the backend to use. Feature support may vary across different backend
  /// versions.
  case vertexAI(
    location: String = "us-central1",
    publisher: String = "google",
    projectId: String,
    version: BackendVersion = .v1beta
  )

  /// Use the [Google AI](https://ai.google.dev/gemini-api/docs) backend.
  ///
  /// - Parameters:
  ///   - version: Version of the backend to use. Feature support may vary across different backend
  /// versions.
  ///   - direct: Only applicable when using the Firebase authentication method. Instead of
  /// communicating through the Firebase
  ///     proxy, communicate directly with the Google AI API.
  case googleAI(
    version: BackendVersion = .v1beta,
    direct: Bool = false
  )
}

/// TODO(daymxn): Decide if we want to even support v1 or just v1beta.
public enum BackendVersion: String, Sendable, Encodable, Equatable {
  /// The stable channel for version 1 of the API.
  // TODO(daymxn): Add error if used with Firebase; Firebase only supports v1beta.
  case v1

  /// The beta channel for version 1 of the API.
  case v1beta // TODO: for vertex this is v1beta1 instead
}
