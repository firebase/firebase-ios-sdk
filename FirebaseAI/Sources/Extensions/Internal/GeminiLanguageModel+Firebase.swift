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

#if compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
  import Foundation
  import GeminiAPIClient
  import GeminiLanguageModel

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel {
    /// Initializes a Gemini language model adapter using Firebase AI configuration.
    ///
    /// - Parameters:
    ///   - firebaseAI: The Firebase AI instance providing credentials and endpoint routing.
    ///   - name: The model name.
    ///   - thinking: An optional thinking configuration. Defaults to `nil`.
    init(firebaseAI: FirebaseAI, name: String, thinking: Thinking? = nil) {
      let endpointURL = firebaseAI.apiConfig.service.endpoint.rawValue
      guard let urlComponents = URLComponents(string: endpointURL) else {
        preconditionFailure("Invalid Gemini API URL: \(endpointURL)")
      }
      guard let host = urlComponents.host else {
        preconditionFailure("Invalid Gemini API hostname in URL: \(endpointURL)")
      }

      self.init(
        modelResource: ModelResource(
          modelID: name,
          urlResourceName: firebaseAI.modelResourceName(modelName: name),
          payloadResourceName: "models/\(name)"
        ),
        endpointConfiguration: EndpointConfiguration(
          host: host,
          port: urlComponents.port,
          apiVersion: firebaseAI.apiConfig.version.rawValue
        ),
        headerProvider: firebaseAI.headerProvider,
        configuration: .ephemeral,
        thinking: thinking
      )
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  fileprivate extension FirebaseAI {
    func headerProvider() async throws -> [String: String] {
      try await firebaseInfo.requestHeaders(
        additionalClientTags: [Constants.foundationModelsRequestTag]
      )
    }
  }
#endif // compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
