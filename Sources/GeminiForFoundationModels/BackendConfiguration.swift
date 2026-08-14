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

  /// Defines the backend configuration for the Gemini language model.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct BackendConfiguration: Hashable, Sendable {
    /// The base URL for the Gemini API.
    let baseURL: URL

    /// Initializes a custom backend configuration.
    ///
    /// - Parameter url: The base URL for the backend.
    public init(baseURL: URL) {
      self.baseURL = baseURL
    }

    /// Returns the configuration for the Gemini Developer API.
    public static func geminiDeveloperAPI() -> BackendConfiguration {
      BackendConfiguration(baseURL: URL(string: "https://generativelanguage.googleapis.com")!)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
