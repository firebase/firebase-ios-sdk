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
class TemplateGenerateImagesRequest: @unchecked Sendable, GenerativeAIRequest {
  typealias Response = ImagenGenerationResponse<ImagenInlineImage>

  func getURL() throws -> URL {
    var urlString =
      "\(apiConfig.service.endpoint.rawValue)/\(apiConfig.version.rawValue)/projects/\(projectID)"
    if case let .vertexAI(_, location) = apiConfig.service {
      urlString += "/locations/\(location)"
    }
    urlString += "/templates/\(template):\(ImageAPIMethod.generateImages.rawValue)"
    guard let url = URL(string: urlString) else {
      throw AILog.makeInternalError(message: "Malformed URL: \(urlString)", code: .malformedURL)
    }
    return url
  }

  let options: RequestOptions

  let apiConfig: APIConfig

  let template: String
  let inputs: [String: TemplateInput]
  let projectID: String

  init(template: String, inputs: [String: TemplateInput], projectID: String,
       apiConfig: APIConfig, options: RequestOptions) {
    self.apiConfig = apiConfig
    self.options = options
    self.template = template
    self.inputs = inputs
    self.projectID = projectID
  }

  enum CodingKeys: String, CodingKey {
    case inputs
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(inputs, forKey: .inputs)
  }
}
