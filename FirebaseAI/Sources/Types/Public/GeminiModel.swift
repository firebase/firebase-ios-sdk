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

#if compiler(>=6.2.3)
  public struct GeminiModel {
    let modelName: String
    let modelResourceName: String
    let firebaseInfo: FirebaseInfo
    let apiConfig: APIConfig
    let safetySettings: [SafetySetting]?
    let toolConfig: ToolConfig?
    let requestOptions: RequestOptions
    let urlSession: URLSession

    init(modelName: String,
         modelResourceName: String,
         firebaseInfo: FirebaseInfo,
         apiConfig: APIConfig,
         safetySettings: [SafetySetting]? = nil,
         toolConfig: ToolConfig? = nil,
         requestOptions: RequestOptions = RequestOptions(),
         urlSession: URLSession = GenAIURLSession.default) {
      self.modelName = modelName
      self.modelResourceName = modelResourceName
      self.firebaseInfo = firebaseInfo
      self.apiConfig = apiConfig
      self.safetySettings = safetySettings
      self.toolConfig = toolConfig
      self.requestOptions = requestOptions
      self.urlSession = urlSession
    }
  }

  extension GeminiModel: LanguageModel {
    public var _modelName: String {
      return modelName
    }

    public func _startSession(tools: [any ToolRepresentable]?,
                              instructions: String?) throws -> any _ModelSession {
      let model = GenerativeModel(
        modelName: modelName,
        modelResourceName: modelResourceName,
        firebaseInfo: firebaseInfo,
        apiConfig: apiConfig,
        generationConfig: nil,
        safetySettings: safetySettings,
        tools: tools?.map { $0.toolRepresentation },
        // TODO: Add toolConfig
        systemInstruction: instructions.map { ModelContent(role: "system", parts: $0) },
        requestOptions: requestOptions,
        urlSession: urlSession
      )

      return GeminiModelSession(model: model, history: [])
    }
  }
#endif // compiler(>=6.2.3)
