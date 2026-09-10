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
  package import Foundation
  public import FoundationModels
  package import GeminiAPIClient

  /// **[Public Preview]** A Gemini language model adapter for the Foundation Models framework.
  ///
  /// > Warning: This API is a public preview and may be subject to change.
  ///
  /// To create an instance of ``GeminiLanguageModel``, use
  /// ``FirebaseAI/geminiLanguageModel(name:)`` on a ``FirebaseAI`` instance:
  /// ```swift
  /// let ai = FirebaseAI.firebaseAI()
  /// let model = ai.geminiLanguageModel(name: "gemini-model-name")
  /// let session = LanguageModelSession(model: model)
  /// ```
  ///
  /// This model conforms to Apple's
  /// [`LanguageModel`](https://developer.apple.com/documentation/foundationmodels/languagemodel)
  /// protocol and can be used with the Foundation Models framework when [initializing](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init%28model:tools:instructions:%29)
  /// a [`LanguageModelSession`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession),
  /// or by [setting the model](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofile/model%28_%29)
  /// on a [`DynamicProfile`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofile).
  ///
  /// For more details on using Gemini to generate content with the Foundation Models framework,
  /// see the getting started
  /// [guide](https://firebase.google.com/docs/ai-logic/apple-foundation-models-framework/get-started).
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GeminiLanguageModel: Sendable {
    /// The API variant used to communicate with Gemini.
    public enum APIVariant: Sendable, Hashable, CaseIterable, CustomStringConvertible {
      /// The standard content generation API (`:streamGenerateContent`).
      case generateContent
      /// The Interactions API (`/interactions`).
      case interactions

      public var description: String {
        switch self {
        case .generateContent:
          return "Generate Content"
        case .interactions:
          return "Interactions"
        }
      }
    }

    /// The configuration for the executor responsible for translating Foundation Models requests to
    /// Gemini API calls.
    public let executorConfiguration: Executor.Configuration

    /// Initializes a new Gemini language model.
    ///
    /// - Parameters:
    ///   - modelResource: The Gemini model resource configuration.
    ///   - endpointConfiguration: The network endpoint configuration.
    ///   - headerProvider: An optional async provider for dynamic headers (such as auth tokens).
    ///   - configuration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
    ///   - apiVariant: The API variant to use. Defaults to `.generateContent`.
    package init(
      modelResource: ModelResource,
      endpointConfiguration: EndpointConfiguration,
      headerProvider: (@Sendable () async throws -> [String: String])? = nil,
      configuration: URLSessionConfiguration = .ephemeral,
      apiVariant: APIVariant = .generateContent
    ) {
      executorConfiguration = Executor.Configuration(
        modelResource: modelResource,
        endpointConfiguration: endpointConfiguration,
        headerProvider: headerProvider.map { HeaderProvider($0) },
        sessionConfiguration: configuration,
        apiVariant: apiVariant
      )
    }
  }

  // MARK: - LanguageModel Conformance

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel: LanguageModel {
    /// The capabilities supported by this language model.
    public var capabilities: LanguageModelCapabilities {
      LanguageModelCapabilities([
        .guidedGeneration,
        .reasoning,
        .toolCalling,
      ])
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
