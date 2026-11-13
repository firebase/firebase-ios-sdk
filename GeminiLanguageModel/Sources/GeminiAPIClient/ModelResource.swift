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

/// Defines the various string representations of a model required for API routing and payloads.
///
/// Since Gemini APIs use Resource-Oriented Design, a single model requires different string
/// formats depending on whether it is being placed in a URL path or serialized into a JSON body.
package struct ModelResource: Sendable, Hashable, Equatable {
  /// The raw, unqualified identifier for the model.
  ///
  /// - Note: While the format is consistent (e.g., `gemini-3.8-flash`), the specific models
  ///   available and their exact identifiers may differ between backend environments.
  let modelID: String

  /// The fully qualified resource name used when constructing HTTP request URLs.
  ///
  /// The format depends on the target backend and whether the request is routed directly
  /// or through Firebase AI Logic.
  ///
  /// ### Gemini Developer API
  /// - **Direct:** `models/{modelID}`
  /// - **Firebase AI Logic:** `projects/{projectID}/models/{modelID}`
  ///
  /// ### Gemini Enterprise Agent Platform
  /// The format is identical for both direct and Firebase AI Logic requests:
  /// - `projects/{projectID}/locations/{locationID}/publishers/google/models/{modelID}`
  let urlResourceName: String

  /// The canonical resource name used when serializing nested JSON payloads.
  ///
  /// Unlike the URL path, the JSON payload format must always use the canonical name
  /// expected by the downstream service, regardless of whether the request is routed directly or
  /// through Firebase AI Logic.
  ///
  /// ### Formats
  /// - **Gemini Developer API:** `models/{modelID}`
  /// - **Gemini Enterprise Agent Platform:** `publishers/google/models/{modelID}`
  let payloadResourceName: String

  /// Creates a new model resource configuration.
  ///
  /// - Parameters:
  ///   - modelID: The raw, unqualified identifier for the model (e.g., `gemini-3.8-flash`).
  ///   - urlResourceName: The fully qualified resource name to be used in HTTP request URL paths.
  ///   - payloadResourceName: The canonical resource name to be serialized into request payloads.
  package init(modelID: String, urlResourceName: String, payloadResourceName: String) {
    self.modelID = modelID
    self.urlResourceName = urlResourceName
    self.payloadResourceName = payloadResourceName
  }
}
