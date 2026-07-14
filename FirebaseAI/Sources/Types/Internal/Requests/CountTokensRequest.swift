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
import GoogleAIDataModels
import AgentPlatformDataModels

struct CountTokensRequest {
  let modelResourceName: String

  let generateContentRequest: GenerateContentRequest
}

extension CountTokensRequest: GenerativeAIRequest {
  typealias Response = CountTokensResponse

  var options: RequestOptions { generateContentRequest.options }

  var apiConfig: APIConfig { generateContentRequest.apiConfig }

  func decodeResponse(from data: Data) throws -> CountTokensResponse {
    let decoder = JSONDecoder()
    switch apiConfig.service {
    case .googleAI:
      struct WireResponse: Decodable {
        let totalTokens: Int?
        let promptTokensDetails: [GoogleAI.ModalityTokenCount]?
      }
      let wire = try decoder.decode(WireResponse.self, from: data)
      return CountTokensResponse(
        totalTokens: wire.totalTokens ?? 0,
        promptTokensDetails: wire.promptTokensDetails?.map { ModalityTokenCount(fromGoogleAI: $0) } ?? []
      )
    case .vertexAI:
      struct WireResponse: Decodable {
        let totalTokens: Int?
        let promptTokensDetails: [AgentPlatform.ModalityTokenCount]?
      }
      let wire = try decoder.decode(WireResponse.self, from: data)
      return CountTokensResponse(
        totalTokens: wire.totalTokens ?? 0,
        promptTokensDetails: wire.promptTokensDetails?.map { ModalityTokenCount(fromAgentPlatform: $0) } ?? []
      )
    }
  }

  func getURL() throws -> URL {
    let version = apiConfig.version.rawValue
    let endpoint = apiConfig.service.endpoint.rawValue
    let urlString = "\(endpoint)/\(version)/\(modelResourceName):countTokens"
    guard let url = URL(string: urlString) else {
      throw AILog.makeInternalError(message: "Malformed URL: \(urlString)", code: .malformedURL)
    }
    return url
  }
}

/// The model's response to a count tokens request.
public struct CountTokensResponse: Sendable {
  /// The total number of tokens in the input given to the model as a prompt.
  public let totalTokens: Int

  /// The breakdown, by modality, of how many tokens are consumed by the prompt.
  public let promptTokensDetails: [ModalityTokenCount]

  init(totalTokens: Int, promptTokensDetails: [ModalityTokenCount]) {
    self.totalTokens = totalTokens
    self.promptTokensDetails = promptTokensDetails
  }
}

// MARK: - Codable Conformances

extension CountTokensRequest: Encodable {
  enum VertexCodingKeys: CodingKey {
    case contents
    case systemInstruction
    case tools
    case generationConfig
  }

  enum DeveloperCodingKeys: CodingKey {
    case generateContentRequest
  }

  func encode(to encoder: any Encoder) throws {
    switch apiConfig.service {
    case .vertexAI:
      try encodeForVertexAI(to: encoder)
    case .googleAI:
      try encodeForDeveloper(to: encoder)
    }
  }

  private func encodeForVertexAI(to encoder: any Encoder) throws {
    let wire = generateContentRequest.toAgentPlatform()
    var container = encoder.container(keyedBy: VertexCodingKeys.self)
    try container.encode(wire.contents, forKey: .contents)
    try container.encodeIfPresent(wire.systemInstruction, forKey: .systemInstruction)
    try container.encodeIfPresent(wire.tools, forKey: .tools)
    try container.encodeIfPresent(wire.generationConfig, forKey: .generationConfig)
  }

  private func encodeForDeveloper(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: DeveloperCodingKeys.self)
    let wire = generateContentRequest.toGoogleAI()
    try container.encode(wire, forKey: .generateContentRequest)
  }
}


