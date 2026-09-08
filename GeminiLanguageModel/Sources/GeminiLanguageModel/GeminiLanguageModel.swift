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

  /// A Gemini language model adapter conforming to Apple's `FoundationModels.LanguageModel`
  /// protocol.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GeminiLanguageModel: Sendable {
    public let executorConfiguration: Executor.Configuration

    /// Initializes a new Gemini language model.
    ///
    /// - Parameters:
    ///   - modelResource: The Gemini model resource configuration.
    ///   - endpointConfiguration: The network endpoint configuration.
    ///   - headerProvider: An optional async provider for dynamic headers (such as auth tokens).
    ///   - configuration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
    package init(
      modelResource: ModelResource,
      endpointConfiguration: EndpointConfiguration,
      headerProvider: (@Sendable () async throws -> [String: String])? = nil,
      configuration: URLSessionConfiguration = .ephemeral
    ) {
      executorConfiguration = Executor.Configuration(
        modelResource: modelResource,
        endpointConfiguration: endpointConfiguration,
        headerProvider: headerProvider.map { HeaderProvider($0) },
        sessionConfiguration: configuration
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
        .reasoning
      ])
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
