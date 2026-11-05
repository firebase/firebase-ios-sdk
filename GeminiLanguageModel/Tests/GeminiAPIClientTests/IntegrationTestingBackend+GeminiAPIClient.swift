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
import GeminiTestUtilities

@testable import GeminiAPIClient

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension IntegrationTestingBackend {
  /// Creates a `GeminiAPIClient` configured for this backend.
  ///
  /// In `record` and `replay` modes, requests are routed through test-server and recorded under
  /// a name derived from the calling test's file and function, so call this method directly
  /// from the test function rather than from a shared helper.
  ///
  /// - Parameters:
  ///   - modelID: The model identifier to use. Defaults to `gemini-3.5-flash-lite`.
  ///   - authenticated: Whether to send credentials. Pass `false` to test unauthenticated
  ///     requests.
  ///   - fileID: The calling test's file; used to name test-server recordings.
  ///   - function: The calling test's function; used to name test-server recordings.
  /// - Returns: A configured `GeminiAPIClient` instance.
  /// - Throws: An error if model resource or credentials resolution fails.
  func makeClient(
    modelID: String = ModelResource.gemini35FlashLiteID,
    authenticated: Bool = true,
    fileID: String = #fileID,
    function: String = #function
  ) throws -> GeminiAPIClient {
    let headerProvider = try makeHeaderProvider(
      recordingName: recordingName(fileID: fileID, function: function),
      authenticated: authenticated
    )
    return GeminiAPIClient(
      modelResource: try modelResource(modelID: modelID),
      endpointConfiguration: endpointConfiguration,
      headerProvider: headerProvider.map { HeaderProvider($0) }
    )
  }
}
