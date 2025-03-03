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

struct APIConfig: Sendable, Hashable {
  let service: Service
  let serviceEndpoint: ServiceEndpoint
  let version: Version

  init(service: Service, serviceEndpoint: ServiceEndpoint, version: Version) {
    if case .vertexAI = service {
      guard serviceEndpoint == .firebaseVertexAIProd else {
        fatalError("""
        The only supported endpoint for Vertex AI is \(ServiceEndpoint.firebaseVertexAIProd).
        """)
      }
      guard version == .v1beta || version == .v1 else {
        fatalError("""
        The only supported versions for Vertex AI are \(Version.v1) and \(Version.v1beta).
        """)
      }
    }

    self.service = service
    self.serviceEndpoint = serviceEndpoint
    self.version = version
  }
}

extension APIConfig {
  enum Service {
    case vertexAI
    case developer
  }
}

extension APIConfig {
  enum ServiceEndpoint: String {
    case firebaseVertexAIProd = "https://firebasevertexai.googleapis.com"
    case firebaseVertexAIStaging = "https://staging-firebasevertexai.sandbox.googleapis.com"
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
