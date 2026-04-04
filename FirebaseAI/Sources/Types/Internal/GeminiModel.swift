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

struct GeminiModel: LanguageModel {
  let firebaseAI: FirebaseAI
  let modelName: String
  let generationConfig: GenerationConfig?
  let safetySettings: [SafetySetting]?
  let toolConfig: ToolConfig?
  let requestOptions: RequestOptions

  init(firebaseAI: FirebaseAI,
       modelName: String,
       generationConfig: GenerationConfig? = nil,
       safetySettings: [SafetySetting]? = nil,
       toolConfig: ToolConfig? = nil,
       requestOptions: RequestOptions = RequestOptions(),
       urlSession: URLSession = GenAIURLSession.default) {
    self.firebaseAI = firebaseAI
    self.modelName = modelName
    self.generationConfig = generationConfig
    self.safetySettings = safetySettings
    self.toolConfig = toolConfig
    self.requestOptions = requestOptions
  }

  func startSession(tools: [any ToolRepresentable]?, instructions: String?) -> any ModelSession {
    let tools = tools?.map { $0.toolRepresentation }
    let model = firebaseAI.generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      tools: tools,
      toolConfig: toolConfig,
      systemInstruction: instructions.map { ModelContent(role: "system", parts: $0) },
      requestOptions: requestOptions
    )

    return GeminiModelSession(model: model, history: [])
  }
}
