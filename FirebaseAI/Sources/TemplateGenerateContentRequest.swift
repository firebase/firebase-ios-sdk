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

/// A request to generate content using a server prompt template.
struct TemplateGenerateContentRequest: Sendable {
  /// The prompt template name or ID to use.
  let template: String

  /// The input variables to substitute into the template.
  let inputs: [String: TemplateInput]

  /// The conversation history for chat sessions.
  let history: [ModelContent]

  /// The Google Cloud or Firebase project ID.
  let projectID: String

  /// Indicates whether the response should be streamed.
  let stream: Bool

  /// The API configuration for the request.
  let apiConfig: APIConfig

  /// Configuration parameters for sending requests to the backend.
  let options: RequestOptions

  /// A list of tools the model may use to generate the next response.
  let tools: [TemplateTool.Internal]?

  /// Tool configuration for any `TemplateTool` specified in the request.
  let toolConfig: TemplateToolConfig?
}

extension TemplateGenerateContentRequest: GenerativeAIRequest {
  typealias Response = GenerateContentResponse

  /// Characters allowed, unescaped, within the template ID path segment.
  ///
  /// `CharacterSet.urlPathAllowed` permits `/` and `:`, which would let a template ID introduce
  /// additional path components or a custom method separator (for example,
  /// `:templateGenerateContent`); both are escaped.
  private static let templateIDAllowedCharacters = CharacterSet.urlPathAllowed
    .subtracting(CharacterSet(charactersIn: "/:"))

  /// Returns the request URL for the server prompt template request.
  ///
  /// - Returns: The fully qualified endpoint `URL`.
  /// - Throws: An error if the URL string is malformed.
  func getURL() throws -> URL {
    var urlString =
      "\(apiConfig.service.endpoint.rawValue)/\(apiConfig.version.rawValue)/projects/\(projectID)"
    if case let .enterprise(_, location) = apiConfig.service {
      urlString += "/locations/\(location)"
    }

    // The template ID is developer-supplied (and commonly sourced from Firebase Remote Config), so
    // escape it rather than interpolating it into the path verbatim.
    guard let encodedTemplate = template.addingPercentEncoding(
      withAllowedCharacters: Self.templateIDAllowedCharacters
    ) else {
      throw AILog.makeInternalError(
        message: "Malformed template ID: \(template)", code: .malformedURL
      )
    }

    if stream {
      urlString += "/templates/\(encodedTemplate):templateStreamGenerateContent?alt=sse"
    } else {
      urlString += "/templates/\(encodedTemplate):templateGenerateContent"
    }
    guard let url = URL(string: urlString) else {
      throw AILog.makeInternalError(message: "Malformed URL: \(urlString)", code: .malformedURL)
    }
    return url
  }
}

// MARK: - Codable Conformances

extension TemplateGenerateContentRequest: Encodable {
  enum CodingKeys: String, CodingKey {
    case inputs
    case history
    case tools
    case toolConfig
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(inputs, forKey: .inputs)
    try container.encode(history, forKey: .history)
    try container.encodeIfPresent(tools, forKey: .tools)
    try container.encodeIfPresent(toolConfig, forKey: .toolConfig)
  }
}
