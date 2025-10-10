
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
public class GenerateImagesRequest: @unchecked Sendable, GenerativeAIRequest {
  public typealias Response = GenerateImagesResponse

  public let url: URL
  public let options: RequestOptions

  let apiConfig: APIConfig

  let template: String
  let variables: [String: TemplateVariable]

  init(template: String, variables: [String: TemplateVariable], apiConfig: APIConfig,
       options: RequestOptions) {
    let modelURL =
      "\(apiConfig.service.endpoint.rawValue)/\(apiConfig.version.rawValue)/\(template)"
    url = URL(string: "\(modelURL):\(ImageAPIMethod.generateImages.rawValue)")!
    self.apiConfig = apiConfig
    self.options = options
    self.template = template
    self.variables = variables
  }

  enum CodingKeys: String, CodingKey {
    case template
    case variables
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(template, forKey: .template)
    try container.encode(variables, forKey: .variables)
  }
}
