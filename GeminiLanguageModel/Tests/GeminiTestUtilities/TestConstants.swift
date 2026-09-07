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
package import GeminiAPIClient

// MARK: - ModelResource Test Constants

extension ModelResource {
  /// Test model ID for `gemini-3.5-flash-lite`.
  package static let gemini35FlashLiteID = "gemini-3.5-flash-lite"

  /// Test URL resource name for `gemini-3.5-flash-lite`.
  package static let gemini35FlashLiteURLResourceName = "models/\(gemini35FlashLiteID)"

  /// Test model resource for `gemini-3.5-flash-lite`.
  package static let gemini35FlashLite = ModelResource(
    modelID: gemini35FlashLiteID,
    urlResourceName: gemini35FlashLiteURLResourceName,
    payloadResourceName: gemini35FlashLiteURLResourceName
  )

  /// Test model ID for `gemini-3.8-flash`.
  package static let gemini38FlashID = "gemini-3.8-flash"

  /// Test URL resource name for `gemini-3.8-flash`.
  package static let gemini38FlashURLResourceName = "models/\(gemini38FlashID)"

  /// Test model resource for `gemini-3.8-flash`.
  package static let gemini38Flash = ModelResource(
    modelID: gemini38FlashID,
    urlResourceName: gemini38FlashURLResourceName,
    payloadResourceName: gemini38FlashURLResourceName
  )
}

// MARK: - EndpointConfiguration Test Constants

extension EndpointConfiguration {
  /// Test Developer API host name.
  package static let geminiDeveloperAPIHost = "generativelanguage.googleapis.com"

  /// Test Developer API version string.
  package static let geminiDeveloperAPIVersion = "v1beta"

  /// Test Developer API endpoint configuration (`generativelanguage.googleapis.com/v1beta`).
  package static let geminiDeveloperAPI = EndpointConfiguration(
    host: geminiDeveloperAPIHost,
    apiVersion: geminiDeveloperAPIVersion
  )

  /// Test Firebase AI Logic host name.
  package static let firebaseAILogicHost = "firebasevertexai.googleapis.com"

  /// Test Firebase AI Logic version string.
  package static let firebaseAILogicAPIVersion = "v1beta"

  /// Test Firebase AI Logic endpoint configuration (`firebasevertexai.googleapis.com/v1beta`).
  package static let firebaseAILogic = EndpointConfiguration(
    host: firebaseAILogicHost,
    apiVersion: firebaseAILogicAPIVersion
  )
}
