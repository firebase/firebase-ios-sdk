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
  #if GeminiDeveloperAPIEnvironmentAuth
    public import Foundation
  #else
    package import Foundation
  #endif
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

    #if GeminiDeveloperAPIEnvironmentAuth
      /// Initializes a new Gemini language model using an API key from the environment.
      ///
      /// The model inspects the `GOOGLE_API_KEY` and `GEMINI_API_KEY` environment variables (preferring
      /// `GOOGLE_API_KEY` if both are set) to authenticate requests with the Gemini Developer API.
      ///
      /// - Parameters:
      ///   - modelID: The model identifier to use (e.g. `"gemini-3.5-flash-lite"`). Defaults to
      ///     `"gemini-3.5-flash-lite"`.
      ///   - configuration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
      ///   - apiVariant: The API variant to use. Defaults to `.generateContent`.
      public init(
        modelID: String = "gemini-3.5-flash-lite",
        configuration: URLSessionConfiguration = .ephemeral,
        apiVariant: APIVariant = .generateContent
      ) {
        self.init(
          modelID: modelID,
          environment: ProcessInfo.processInfo.environment,
          configuration: configuration,
          apiVariant: apiVariant
        )
      }

      /// Initializes a new Gemini language model with an explicit environment dictionary.
      ///
      /// - Parameters:
      ///   - modelID: The model identifier to use. Defaults to `"gemini-3.5-flash-lite"`.
      ///   - environment: The environment dictionary containing `GOOGLE_API_KEY` or `GEMINI_API_KEY`.
      ///   - configuration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
      ///   - apiVariant: The API variant to use. Defaults to `.generateContent`.
      package init(
        modelID: String = "gemini-3.5-flash-lite",
        environment: [String: String],
        configuration: URLSessionConfiguration = .ephemeral,
        apiVariant: APIVariant = .generateContent
      ) {
        let resource = ModelResource(
          modelID: modelID,
          urlResourceName: "models/\(modelID)",
          payloadResourceName: "models/\(modelID)"
        )
        self.init(
          modelResource: resource,
          endpointConfiguration: .geminiDeveloperAPI,
          headerProvider: {
            guard let apiKey = Self.resolveAPIKey(from: environment) else {
              throw GeminiLanguageModel.Error.missingAPIKey(
                GeminiLanguageModel.Error.MissingAPIKey(
                  debugDescription:
                    "A Gemini API key is required. Set the GOOGLE_API_KEY or GEMINI_API_KEY environment variable."
                )
              )
            }
            return ["x-goog-api-key": apiKey]
          },
          configuration: configuration,
          apiVariant: apiVariant
        )
      }

      private static func resolveAPIKey(from environment: [String: String]) -> String? {
        if let googleKey = environment["GOOGLE_API_KEY"], !googleKey.isEmpty {
          return googleKey
        }
        if let geminiKey = environment["GEMINI_API_KEY"], !geminiKey.isEmpty {
          return geminiKey
        }
        return nil
      }
    #endif  // GeminiDeveloperAPIEnvironmentAuth
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
