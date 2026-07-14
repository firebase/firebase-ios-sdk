// Copyright 2023 Google LLC
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

struct GenerateContentRequest: Sendable {
  /// Model name.
  let model: String

  let contents: [ModelContent]
  let generationConfig: GenerationConfig?
  let safetySettings: [SafetySetting]?
  let tools: [Tool]?
  let toolConfig: ToolConfig?
  let systemInstruction: ModelContent?

  let apiConfig: APIConfig
  let apiMethod: APIMethod
  let options: RequestOptions
}

// MARK: - Mappings

import GoogleAIDataModels
import AgentPlatformDataModels

extension GenerateContentRequest {
  package func toGoogleAI() -> GoogleAI.GenerateContentRequest {
    GoogleAI.GenerateContentRequest(
      contents: contents.map { $0.toGoogleAI() },
      generationConfig: generationConfig?.toGoogleAI(),
      model: apiMethod == .countTokens ? model : nil,
      safetySettings: safetySettings?.map { $0.toGoogleAI() },
      systemInstruction: systemInstruction?.toGoogleAI(),
      toolConfig: toolConfig?.toGoogleAI(),
      tools: tools?.map { $0.toGoogleAI() }
    )
  }

  package func toAgentPlatform() -> AgentPlatform.GenerateContentRequest {
    AgentPlatform.GenerateContentRequest(
      contents: contents.map { $0.toAgentPlatform() },
      generationConfig: generationConfig?.toAgentPlatform(),
      model: apiMethod == .countTokens ? model : nil,
      safetySettings: safetySettings?.map { $0.toAgentPlatform() },
      systemInstruction: systemInstruction?.toAgentPlatform(),
      toolConfig: toolConfig?.toAgentPlatform(),
      tools: tools?.map { $0.toAgentPlatform() }
    )
  }
}

extension GenerateContentRequest {
  enum APIMethod: String {
    case generateContent
    case streamGenerateContent
    case countTokens
  }
}

extension GenerateContentRequest: GenerativeAIRequest {
  typealias Response = GenerateContentResponse

  func decodeResponse(from data: Data) throws -> GenerateContentResponse {
    let decoder = JSONDecoder()
    switch apiConfig.service {
    case .googleAI:
      let wire = try decoder.decode(GoogleAI.GenerateContentResponse.self, from: data)
      return GenerateContentResponse(fromGoogleAI: wire)
    case .vertexAI:
      let wire = try decoder.decode(AgentPlatform.GenerateContentResponse.self, from: data)
      return GenerateContentResponse(fromAgentPlatform: wire)
    }
  }

  func getURL() throws -> URL {
    let modelURL = "\(apiConfig.service.endpoint.rawValue)/\(apiConfig.version.rawValue)/\(model)"
    let urlString: String
    switch apiMethod {
    case .generateContent:
      urlString = "\(modelURL):\(apiMethod.rawValue)"
    case .streamGenerateContent:
      urlString = "\(modelURL):\(apiMethod.rawValue)?alt=sse"
    case .countTokens:
      throw AILog.makeInternalError(
        message: "\(Self.self) should be a property of \(CountTokensRequest.self).",
        code: .malformedURL
      )
    }
    guard let url = URL(string: urlString) else {
      throw AILog.makeInternalError(message: "Malformed URL: \(urlString)", code: .malformedURL)
    }
    return url
  }
}
