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

import FirebaseCore
import Foundation

#if compiler(>=6.2.3)
  /// A Gemini or Gemma model accessed via the Gemini Developer API or the Vertex AI API.
  ///
  /// **Public Preview**: This API is a public preview and may be subject to change.
  ///
  /// To create a ``GeminiModel`` instance, see
  /// ``FirebaseAI/geminiModel(name:safetySettings:requestOptions:)``.
  public struct GeminiModel {
    public struct ModelConfig: Sendable, Hashable {
      let firebaseAppName: String
      let apiConfig: APIConfig
      let useLimitedUseAppCheckTokens: Bool

      public let modelName: String
      public let safetySettings: [SafetySetting]?
      public let serverTools: [ServerTool]?
      public let requestOptions: RequestOptions

      public var firebaseAI: FirebaseAI {
        let firebaseApp = FirebaseApp.app(name: firebaseAppName)
        return FirebaseAI.createInstance(
          app: firebaseApp,
          apiConfig: apiConfig,
          useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
        )
      }
    }

    public let modelConfig: ModelConfig
    let modelResourceName: String
    let firebaseInfo: FirebaseInfo
    let toolConfig: ToolConfig?
    let urlSession: URLSession

    init(modelName: String,
         modelResourceName: String,
         firebaseInfo: FirebaseInfo,
         apiConfig: APIConfig,
         safetySettings: [SafetySetting]? = nil,
         serverTools: [ServerTool]? = nil,
         toolConfig: ToolConfig? = nil,
         requestOptions: RequestOptions = RequestOptions(),
         urlSession: URLSession = GenAIURLSession.default) {
      modelConfig = ModelConfig(
        firebaseAppName: firebaseInfo.app.name,
        apiConfig: apiConfig,
        useLimitedUseAppCheckTokens: firebaseInfo.useLimitedUseAppCheckTokens,
        modelName: modelName,
        safetySettings: safetySettings,
        serverTools: serverTools,
        requestOptions: requestOptions,
      )
      self.modelResourceName = modelResourceName
      self.firebaseInfo = firebaseInfo
      self.toolConfig = toolConfig
      self.urlSession = urlSession
    }
  }

  extension GeminiModel: LanguageModel {
    /// Returns the name of the model.
    ///
    /// > Important: This property is for **internal use only** and may change at any time.
    public var _modelName: String {
      return modelConfig.modelName
    }

    /// Returns a new session for this model.
    ///
    /// > Important: This method is for **internal use only** and may change at any time.
    public func _startSession(tools: [any ToolRepresentable]?,
                              instructions: String?) throws -> any _ModelSession {
      let model = GenerativeModel(
        modelName: modelConfig.modelName,
        modelResourceName: modelResourceName,
        firebaseInfo: firebaseInfo,
        apiConfig: modelConfig.apiConfig,
        generationConfig: nil,
        safetySettings: modelConfig.safetySettings,
        tools: tools?.map { $0.toolRepresentation },
        // TODO: Add toolConfig
        systemInstruction: instructions.map { ModelContent(role: "system", parts: $0) },
        requestOptions: modelConfig.requestOptions,
        urlSession: urlSession
      )

      return GeminiModelSession(model: model, history: [])
    }
  }
#endif // compiler(>=6.2.3)
