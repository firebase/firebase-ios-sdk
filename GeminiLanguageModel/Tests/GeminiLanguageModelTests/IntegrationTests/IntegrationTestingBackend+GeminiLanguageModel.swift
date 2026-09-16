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

#if canImport(FoundationModels) && compiler(>=6.4)
  import Foundation
  import FoundationModels
  import GeminiAPIClient
  import GeminiTestUtilities

  @testable import GeminiLanguageModel

  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  extension IntegrationTestingBackend {
    /// Creates a `GeminiLanguageModel` configured for this backend.
    ///
    /// - Parameter modelID: The model identifier to use. Defaults to `gemini-3.5-flash-lite`.
    /// - Returns: A configured `GeminiLanguageModel` instance.
    /// - Throws: An error if model resource or credentials resolution fails.
    func makeModel(
      modelID: String = ModelResource.gemini35FlashLiteID
    ) async throws -> GeminiLanguageModel {
      GeminiLanguageModel(
        modelResource: try modelResource(modelID: modelID),
        endpointConfiguration: endpointConfiguration,
        headerProvider: try await makeHeaderProvider()
      )
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
