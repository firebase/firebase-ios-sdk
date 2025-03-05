// Copyright 2024 Google LLC
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
struct ImagenGenerationRequest<ImageType: ImagenImageRepresentable>: Sendable {
  let model: String
  let apiConfig: APIConfig
  let options: RequestOptions
  let instances: [ImageGenerationInstance]
  let parameters: ImageGenerationParameters

  init(model: String,
       apiConfig: APIConfig,
       options: RequestOptions,
       instances: [ImageGenerationInstance],
       parameters: ImageGenerationParameters) {
    self.model = model
    self.apiConfig = apiConfig
    self.options = options
    self.instances = instances
    self.parameters = parameters
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenGenerationRequest: GenerativeAIRequest where ImageType: Decodable {
  typealias Response = ImagenGenerationResponse<ImageType>

  var url: URL {
    return URL(string:
      "\(apiConfig.service.endpoint.rawValue)/\(apiConfig.version.rawValue)/\(model):predict")!
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenGenerationRequest: Encodable {
  enum CodingKeys: CodingKey {
    case instances
    case parameters
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(instances, forKey: .instances)
    try container.encode(parameters, forKey: .parameters)
  }
}
