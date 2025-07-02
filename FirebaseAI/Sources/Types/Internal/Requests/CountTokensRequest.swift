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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct CountTokensRequest {
  let modelResourceName: String

  let generateContentRequest: GenerateContentRequest
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension CountTokensRequest: GenerativeAIRequest {
  typealias Response = CountTokensResponse

  var options: RequestOptions { generateContentRequest.options }

  var apiConfig: APIConfig { generateContentRequest.apiConfig }

  var url: URL {
    let version = apiConfig.version.rawValue
    let endpoint = apiConfig.service.endpoint.rawValue
    return URL(string: "\(endpoint)/\(version)/\(modelResourceName):countTokens")!
  }
}

/// The model's response to a count tokens request.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct CountTokensResponse: Sendable {
  /// The total number of tokens in the input given to the model as a prompt.
  public let totalTokens: Int

  /// The breakdown, by modality, of how many tokens are consumed by the prompt.
  public let promptTokensDetails: [ModalityTokenCount]
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
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
    var container = encoder.container(keyedBy: VertexCodingKeys.self)
    try container.encode(generateContentRequest.contents, forKey: .contents)
    try container.encodeIfPresent(
      generateContentRequest.systemInstruction, forKey: .systemInstruction
    )
    try container.encodeIfPresent(generateContentRequest.tools, forKey: .tools)
    try container.encodeIfPresent(
      generateContentRequest.generationConfig, forKey: .generationConfig
    )
  }

  private func encodeForDeveloper(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: DeveloperCodingKeys.self)
    try container.encode(generateContentRequest, forKey: .generateContentRequest)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension CountTokensResponse: Decodable {
  enum CodingKeys: CodingKey {
    case totalTokens
    case promptTokensDetails
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens) ?? 0
    promptTokensDetails =
      try container.decodeIfPresent([ModalityTokenCount].self, forKey: .promptTokensDetails) ?? []
  }
}
