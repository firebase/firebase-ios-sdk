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

enum ImageAPIMethod: String {
  case generateImages = "templatePredict"
}

struct TemplateImagenGenerationRequest<ImageType: ImagenImageRepresentable>: Sendable {
  typealias Response = ImagenGenerationResponse<ImageType>

  let template: String
  let inputs: [String: TemplateInput]
  let projectID: String
  let apiConfig: APIConfig
  let options: RequestOptions

  init(template: String, inputs: [String: TemplateInput], projectID: String,
       apiConfig: APIConfig, options: RequestOptions) {
    self.template = template
    self.inputs = inputs
    self.projectID = projectID
    self.apiConfig = apiConfig
    self.options = options
  }
}

extension TemplateImagenGenerationRequest: GenerativeAIRequest where ImageType: Decodable {
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
}

extension TemplateImagenGenerationRequest: Encodable {
  enum CodingKeys: String, CodingKey {
    case inputs
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(inputs, forKey: .inputs)
  }
}
