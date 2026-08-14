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

  #if canImport(FoundationNetworking)
    import FoundationNetworking
  #endif

  /// A Gemini language model adapter conforming to Apple's `FoundationModels.LanguageModel` protocol.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GeminiLanguageModel: Sendable {
    /// The model identifier (e.g. `"gemini-3.5-flash-lite"`).
    let name: String

    /// The backend configuration for the Gemini API.
    let backendConfiguration: BackendConfiguration

    /// An optional async closure providing HTTP headers for authentication.
    let headerProvider: (@Sendable () async throws -> [String: String])?

    /// The URL session configuration used for network requests.
    let configuration: URLSessionConfiguration

    /// Initializes a new Gemini language model.
    ///
    /// - Parameters:
    ///   - name: The Gemini model identifier.
    ///   - backendConfiguration: The backend configuration.
    ///   - headerProvider: An optional async provider for dynamic headers (such as auth tokens).
    ///   - configuration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
    public init(
      name: String,
      backendConfiguration: BackendConfiguration,
      headerProvider: (@Sendable () async throws -> [String: String])? = nil,
      configuration: URLSessionConfiguration = .ephemeral
    ) {
      self.name = name
      self.backendConfiguration = backendConfiguration
      self.headerProvider = headerProvider
      self.configuration = configuration
    }

    #if DirectGeminiDeveloperAPIAccess
      /// Convenience initializer using a static API key.
      ///
      /// - Parameters:
      ///   - name: The Gemini model identifier.
      ///   - apiKey: The Google Gemini API key.
      ///   - backendConfiguration: The backend configuration. Defaults to `.geminiDeveloperAPI()`.
      ///   - configuration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
      @available(
        iOS, unavailable,
        message: "Use Firebase AI Logic to securely access Gemini models in iOS apps."
      )
      @available(
        watchOS, unavailable,
        message: "Use Firebase AI Logic to securely access Gemini models in watchOS apps."
      )
      @available(
        visionOS, unavailable,
        message: "Use Firebase AI Logic to securely access Gemini models in visionOS apps."
      )
      @available(
        tvOS, unavailable,
        message: "Use Firebase AI Logic to securely access Gemini models in tvOS apps."
      )
      public init(
        name: String,
        apiKey: String,
        backendConfiguration: BackendConfiguration = .geminiDeveloperAPI(),
        configuration: URLSessionConfiguration = .ephemeral
      ) {
        self.init(
          name: name,
          backendConfiguration: backendConfiguration,
          headerProvider: { @Sendable in
            ["x-goog-api-key": apiKey]
          },
          configuration: configuration
        )
      }
    #endif  // DirectGeminiDeveloperAPIAccess
  }

  // MARK: - LanguageModel Conformance

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel: LanguageModel {
    /// The capabilities supported by this language model.
    public var capabilities: LanguageModelCapabilities {
      LanguageModelCapabilities([
        .reasoning
      ])
    }

    /// The executor configuration value for caching executors.
    public var executorConfiguration: Executor.Configuration {
      Executor.Configuration(
        name: name,
        backendConfiguration: backendConfiguration
      )
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
