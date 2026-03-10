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

#if os(Linux)
  import FoundationNetworking
#endif

/// API backend to communicate with.
public enum Backend: Sendable {
  /// Use the [Vertex AI](https://cloud.google.com/vertex-ai/docs) backend.
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
  ///    versions.
  ///   - direct: Only applicable when using the Firebase authentication method. Instead of
  ///     communicating through the Firebase proxy, communicate directly with the Google AI API.
  case googleAI(
    version: BackendVersion = .v1beta,
    direct: Bool = false
  )
}

public enum BackendVersion: String, Sendable, Encodable, Equatable {
  /// The stable channel for version 1 of the API.
  case v1

  /// The beta channel for version 1 of the API.
  case v1beta
}

