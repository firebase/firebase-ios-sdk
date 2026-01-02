// Copyright 2025 Google LLC
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
struct TemplateGenerateContentRequest: Sendable {
  let template: String
  let inputs: [String: TemplateInput]
  let history: [ModelContent]
  let projectID: String
  let stream: Bool
  let apiConfig: APIConfig
  let options: RequestOptions
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension TemplateGenerateContentRequest: Encodable {
  enum CodingKeys: String, CodingKey {
    case inputs
    case history
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(inputs, forKey: .inputs)
    try container.encode(history, forKey: .history)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension TemplateGenerateContentRequest: GenerativeAIRequest {
  typealias Response = GenerateContentResponse

  func getURL() throws -> URL {
    guard case let .cloud(config) = apiConfig else {
      throw AILog.makeInternalError(
        message: "Templates not supported on-device",
        code: .unsupportedConfig
      )
    }

    var urlString =
      "\(config.service.endpoint.rawValue)/\(config.version.rawValue)/projects/\(projectID)"
    if case let .vertexAI(_, location) = config.service {
      urlString += "/locations/\(location)"
    }

    if stream {
      urlString += "/templates/\(template):templateStreamGenerateContent?alt=sse"
    } else {
      urlString += "/templates/\(template):templateGenerateContent"
    }
    guard let url = URL(string: urlString) else {
      throw AILog.makeInternalError(message: "Malformed URL: \(urlString)", code: .malformedURL)
    }
    return url
  }
}
