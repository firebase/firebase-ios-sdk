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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension GenerateContentRequest: Encodable {
  enum CodingKeys: String, CodingKey {
    case contents
    case generationConfig
    case safetySettings
    case tools
    case toolConfig
    case systemInstruction
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension GenerateContentRequest {
  enum APIMethod: String {
    case generateContent
    case streamGenerateContent
    case countTokens
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension GenerateContentRequest: GenerativeAIRequest {
  typealias Response = GenerateContentResponse

  var url: URL {
    let modelURL = "\(apiConfig.serviceEndpoint.rawValue)/\(apiConfig.version.rawValue)/\(model)"
    switch apiMethod {
    case .generateContent:
      return URL(string: "\(modelURL):\(apiMethod.rawValue)")!
    case .streamGenerateContent:
      return URL(string: "\(modelURL):\(apiMethod.rawValue)?alt=sse")!
    case .countTokens:
      fatalError("\(Self.self) should be a property of \(CountTokensRequest.self).")
    }
  }
}
