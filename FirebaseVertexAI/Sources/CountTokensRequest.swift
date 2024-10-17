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
  let model: String

  let contents: [ModelContent]
  let systemInstruction: ModelContent?
  let tools: [Tool]?
  let generationConfig: GenerationConfig?

  let options: RequestOptions
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension CountTokensRequest: GenerativeAIRequest {
  typealias Response = CountTokensResponse

  var url: URL {
    URL(string: "\(Constants.baseURL)/\(options.apiVersion)/\(model):countTokens")!
  }
}

/// The model's response to a count tokens request.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct CountTokensResponse {
  /// The total number of tokens in the input given to the model as a prompt.
  public let totalTokens: Int

  /// The total number of billable characters in the text input given to the model as a prompt.
  ///
  /// > Important: This does not include billable image, video or other non-text input. See
  /// [Vertex AI pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing) for details.
  public let totalBillableCharacters: Int?
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension CountTokensRequest: Encodable {
  enum CodingKeys: CodingKey {
    case contents
    case systemInstruction
    case tools
    case generationConfig
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension CountTokensResponse: Decodable {}
