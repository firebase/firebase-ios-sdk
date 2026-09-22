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
  let tools: [TemplateTool]?

  /// Tool configuration for any `TemplateTool` specified in the request.
  let toolConfig: TemplateToolConfig?
}

/// Tool details that the model may use to generate a response.
///
/// A tool is a piece of code that enables the system to interact with external systems to perform
/// an action, or set of actions, outside of knowledge and scope of the model. A tool object should
/// contain exactly one type of tool.
struct TemplateTool: Sendable, Equatable {
  /// A list of user-provided functions for function calling.
  ///
  /// For functions whose names are listed in the template frontmatter, the model may decide to
  /// call a subset of these functions by populating `FunctionCall` in the response. The user should
  /// provide a `FunctionResponse` for each function call in the next turn.
  let templateFunctions: [TemplateTool.FunctionDeclaration]?

  /// Tool to retrieve public maps data for grounding, powered by Google.
  struct GoogleMaps: Sendable, Equatable {
    /// If true, include the widget context token in the response.
    let enableWidget: Bool?

    /// Initializes a new Google Maps tool.
    ///
    /// - Parameter enableWidget: If `true`, include the widget context token in the response.
    init(enableWidget: Bool? = nil) {
      self.enableWidget = enableWidget
    }
  }

  /// A Google Maps tool.
  let googleMaps: GoogleMaps?

  /// Initializes a new `TemplateTool`.
  ///
  /// - Parameters:
  ///   - templateFunctions: A list of user-provided functions for function calling.
  ///   - googleMaps: A Google Maps tool configuration.
  init(templateFunctions: [TemplateTool.FunctionDeclaration]? = nil,
       googleMaps: GoogleMaps? = nil) {
    self.templateFunctions = templateFunctions
    self.googleMaps = googleMaps
  }
}

extension TemplateTool {
  /// Structured representation of a function declaration as defined by the
  /// [OpenAPI 3.0 specification](https://spec.openapis.org/oas/v3.0.3).
  ///
  /// This is a representation of a block of code that can be used as a `Tool` by the model and
  /// executed by the client. The name of the function must be listed in the template frontmatter
  /// for the model to be able to call it.
  struct FunctionDeclaration: Sendable, Equatable {
    /// The name of the function to call.
    let name: String

    /// Describes the parameters to the function in JSON Schema format.
    ///
    /// The schema must describe an object where the properties are the parameters to the function.
    /// For example:
    ///
    /// ```json
    /// {
    ///   "type": "object",
    ///   "properties": {
    ///     "name": { "type": "string" },
    ///     "age": { "type": "integer" }
    ///   },
    ///   "additionalProperties": false,
    ///   "required": ["name", "age"],
    ///   "propertyOrdering": ["name", "age"]
    /// }
    /// ```
    let inputSchema: JSONObject?

    /// Describes the output from this function in JSON Schema format.
    ///
    /// The value specified by the schema is the response value of the function.
    let outputSchema: JSONObject?

    /// Initializes a new `FunctionDeclaration`.
    ///
    /// - Parameters:
    ///   - name: The name of the function to call.
    ///   - inputSchema: Describes the parameters to the function in JSON Schema format.
    ///   - outputSchema: Describes the output from this function in JSON Schema format.
    init(name: String, inputSchema: JSONObject? = nil, outputSchema: JSONObject? = nil) {
      self.name = name
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
    }
  }
}

extension TemplateGenerateContentRequest: GenerativeAIRequest {
  typealias Response = GenerateContentResponse

  /// Returns the request URL for the server prompt template request.
  ///
  /// - Returns: The fully qualified endpoint `URL`.
  /// - Throws: An error if the URL string is malformed.
  func getURL() throws -> URL {
    var urlString =
      "\(apiConfig.service.endpoint.rawValue)/\(apiConfig.version.rawValue)/projects/\(projectID)"
    if case let .agentPlatform(_, location) = apiConfig.service {
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

extension TemplateTool {
  /// Initializes a `TemplateTool` by converting from a ``Tool``.
  ///
  /// - Parameter tool: The ``Tool`` to convert.
  /// - Throws: An `EncodingError.invalidValue` if the tool contains unsupported tools (such as
  ///   Google Search, code execution, or URL context), does not contain any tool type, or contains
  ///   multiple tool types.
  init(_ tool: Tool) throws {
    guard tool.googleSearch == nil else {
      throw EncodingError.invalidValue(
        tool,
        .init(
          codingPath: [],
          debugDescription: "Google Search grounding is not supported in Server Prompt Templates."
        )
      )
    }
    guard tool.codeExecution == nil else {
      throw EncodingError.invalidValue(
        tool,
        .init(
          codingPath: [],
          debugDescription: "Code execution is not supported in Server Prompt Templates."
        )
      )
    }
    guard tool.urlContext == nil else {
      throw EncodingError.invalidValue(
        tool,
        .init(
          codingPath: [],
          debugDescription: "URL context is not supported in Server Prompt Templates."
        )
      )
    }

    let hasFunctions = tool.functionDeclarations != nil
    let hasMaps = tool.googleMaps != nil

    guard hasFunctions || hasMaps else {
      throw EncodingError.invalidValue(
        tool,
        .init(codingPath: [], debugDescription: "A Tool must contain at least one tool type.")
      )
    }

    guard !(hasFunctions && hasMaps) else {
      throw EncodingError.invalidValue(
        tool,
        .init(codingPath: [], debugDescription: "A Tool must contain exactly one type of tool.")
      )
    }

    if let functionDeclarations = tool.functionDeclarations {
      let templateFunctions = try functionDeclarations.map {
        try TemplateTool.FunctionDeclaration($0)
      }
      self.init(templateFunctions: templateFunctions)
    } else {
      self.init(googleMaps: TemplateTool.GoogleMaps())
    }
  }
}

extension TemplateTool.FunctionDeclaration {
  /// Initializes a `TemplateTool.FunctionDeclaration` by converting from a
  /// ``FunctionDeclaration``.
  ///
  /// - Parameter functionDeclaration: The ``FunctionDeclaration`` to convert.
  /// - Throws: An error if parameter schema conversion fails.
  init(_ functionDeclaration: FunctionDeclaration) throws {
    let inputSchema: JSONObject?
    if let parameters = functionDeclaration.parameters {
      inputSchema = parameters.toJSONSchema()
    } else if let parametersJSONSchema = functionDeclaration.parametersJSONSchema {
      inputSchema = try parametersJSONSchema.toGeminiJSONSchema()
    } else {
      inputSchema = nil
    }

    self.init(
      name: functionDeclaration.name,
      inputSchema: inputSchema,
      outputSchema: nil
    )
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

extension TemplateTool: Encodable {}
extension TemplateTool.FunctionDeclaration: Encodable {}
extension TemplateTool.GoogleMaps: Encodable {}
