// Copyright 2026 Google LLC
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
package import GeminiAPIDataModels

// MARK: - Chat Completion Request

/// An OpenAI-compatible chat completion request.
///
/// OrcaRouter speaks the OpenAI wire format, so the SDK's Gemini-shaped request is translated into
/// this shape and the response is translated back. Nothing outside this file needs to know which
/// format is on the wire.
package struct OrcaRouterChatCompletionRequest: Encodable, Sendable, Equatable {
  /// One message in the conversation.
  package struct Message: Encodable, Sendable, Equatable {
    /// The role: `system`, `user`, `assistant`, or `tool`.
    package let role: String
    /// The message content, when it is not a tool result.
    package let content: Content?
    /// The identifier of the tool call this message answers.
    package let toolCallID: String?
    /// The tool calls the assistant requested.
    package let toolCalls: [ToolCall]?

    package init(
      role: String,
      content: Content?,
      toolCallID: String? = nil,
      toolCalls: [ToolCall]? = nil
    ) {
      self.role = role
      self.content = content
      self.toolCallID = toolCallID
      self.toolCalls = toolCalls
    }
  }

  /// Message content: either a plain string or an array of typed parts.
  package enum Content: Encodable, Sendable, Equatable {
    case text(String)
    case parts([ContentPart])

    package func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .text(let value):
        try container.encode(value)
      case .parts(let value):
        try container.encode(value)
      }
    }
  }

  /// A typed content part.
  package struct ContentPart: Encodable, Sendable, Equatable {
    /// The part type: `text`, `image_url`, or `input_audio`.
    package let type: String
    /// The text, for a `text` part.
    package let text: String?
    /// The image, for an `image_url` part.
    package let imageURL: ImageURL?
    /// The audio, for an `input_audio` part.
    package let inputAudio: InputAudio?

    package init(type: String, text: String?, imageURL: ImageURL?, inputAudio: InputAudio?) {
      self.type = type
      self.text = text
      self.imageURL = imageURL
      self.inputAudio = inputAudio
    }

    enum CodingKeys: String, CodingKey {
      case type
      case text
      case imageURL = "image_url"
      case inputAudio = "input_audio"
    }
  }

  /// An image reference, either a data URL or a remote URL.
  package struct ImageURL: Encodable, Sendable, Equatable {
    package let url: String
    package init(url: String) { self.url = url }
  }

  /// Inline audio content.
  package struct InputAudio: Encodable, Sendable, Equatable {
    package let data: String
    package let format: String
    package init(data: String, format: String) {
      self.data = data
      self.format = format
    }
  }

  /// A tool call requested by the assistant.
  package struct ToolCall: Encodable, Sendable, Equatable {
    /// A function invocation.
    package struct Function: Encodable, Sendable, Equatable {
      package let name: String
      package let arguments: String
      package init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
      }
    }

    package let id: String?
    package let type: String?
    package let function: Function?

    package init(id: String?, type: String?, function: Function?) {
      self.id = id
      self.type = type
      self.function = function
    }
  }

  /// A tool the model may call.
  package struct Tool: Encodable, Sendable, Equatable {
    /// A function declaration.
    package struct Function: Encodable, Sendable, Equatable {
      package let name: String
      package let description: String?
      package let parameters: JSONValue?
      package init(name: String, description: String?, parameters: JSONValue?) {
        self.name = name
        self.description = description
        self.parameters = parameters
      }
    }

    package let type: String
    package let function: Function
    package init(type: String = "function", function: Function) {
      self.type = type
      self.function = function
    }
  }

  /// How the model should choose tools.
  package struct ToolChoice: Encodable, Sendable, Equatable {
    package let type: String
    package let function: Function?

    /// A named function to force.
    package struct Function: Encodable, Sendable, Equatable {
      package let name: String
      package init(name: String) { self.name = name }
    }

    package init(type: String, function: Function? = nil) {
      self.type = type
      self.function = function
    }
  }

  /// A response format constraint.
  package struct ResponseFormat: Encodable, Sendable, Equatable {
    package let type: String
    package let jsonSchema: JSONValue?

    package init(type: String, jsonSchema: JSONValue? = nil) {
      self.type = type
      self.jsonSchema = jsonSchema
    }

    enum CodingKeys: String, CodingKey {
      case type
      case jsonSchema = "json_schema"
    }
  }

  package let model: String
  package let messages: [Message]
  package let stream: Bool?
  package let temperature: Double?
  package let topP: Double?
  package let maxTokens: Int?
  package let stop: [String]?
  package let tools: [Tool]?
  package let toolChoice: ToolChoice?
  package let responseFormat: ResponseFormat?
  package let streamOptions: StreamOptions?

  /// Streaming options; `include_usage` makes the final chunk carry usage metadata.
  package struct StreamOptions: Encodable, Sendable, Equatable {
    package let includeUsage: Bool
    package init(includeUsage: Bool = true) {
      self.includeUsage = includeUsage
    }

    enum CodingKeys: String, CodingKey {
      case includeUsage = "include_usage"
    }
  }

  enum CodingKeys: String, CodingKey {
    case model
    case messages
    case stream
    case temperature
    case topP = "top_p"
    case maxTokens = "max_tokens"
    case stop
    case tools
    case toolChoice = "tool_choice"
    case responseFormat = "response_format"
    case streamOptions = "stream_options"
  }
}

// MARK: - Request Translation

/// Translates between the SDK's Gemini-shaped data models and the OpenAI-compatible wire format
/// that OrcaRouter speaks.
package enum OrcaRouterRequestTranslator {
  /// Builds an OpenAI-compatible request from a Gemini-shaped generate-content request.
  ///
  /// - Parameters:
  ///   - request: The SDK request.
  ///   - modelID: The OrcaRouter model identifier, which is sent verbatim in the `model` field.
  ///   - streaming: Whether the response will be streamed.
  /// - Returns: The wire-format request.
  package static func chatCompletionRequest(
    from request: GenerateContentRequest,
    modelID: String,
    streaming: Bool
  ) -> OrcaRouterChatCompletionRequest {
    var messages: [OrcaRouterChatCompletionRequest.Message] = []

    if let systemInstruction = request.systemInstruction {
      let text = textOnly(systemInstruction)
      if !text.isEmpty {
        messages.append(
          OrcaRouterChatCompletionRequest.Message(
            role: "system",
            content: .text(text)
          )
        )
      }
    }

    for content in request.contents {
      messages.append(contentsOf: Self.messages(from: content))
    }

    let generationConfig = request.generationConfig
    return OrcaRouterChatCompletionRequest(
      model: modelID,
      messages: messages,
      stream: streaming,
      temperature: generationConfig?.temperature,
      topP: generationConfig?.topP,
      maxTokens: generationConfig?.maxOutputTokens,
      stop: generationConfig?.stopSequences.flatMap { $0.isEmpty ? nil : $0 },
      tools: tools(from: request.tools),
      toolChoice: toolChoice(from: request.toolConfig),
      responseFormat: responseFormat(from: generationConfig),
      streamOptions: streaming ? OrcaRouterChatCompletionRequest.StreamOptions() : nil
    )
  }

  /// Splits one Gemini content into OpenAI messages.
  ///
  /// A content carrying function responses becomes one `tool` message per response, which is how
  /// the OpenAI format reports tool results.
  static func messages(
    from content: Content
  ) -> [OrcaRouterChatCompletionRequest.Message] {
    var results: [OrcaRouterChatCompletionRequest.Message] = []
    var parts: [OrcaRouterChatCompletionRequest.ContentPart] = []
    var toolCalls: [OrcaRouterChatCompletionRequest.ToolCall] = []

    for part in content.parts ?? [] {
      switch part.data {
      case .text(let value):
        parts.append(
          OrcaRouterChatCompletionRequest.ContentPart(
            type: "text",
            text: value,
            imageURL: nil,
            inputAudio: nil
          )
        )

      case .inlineData(let blob):
        if let mediaPart = mediaPart(from: blob) {
          parts.append(mediaPart)
        }

      case .fileData(let file):
        if let mediaPart = mediaPart(from: file) {
          parts.append(mediaPart)
        }

      case .functionCall(let call):
        toolCalls.append(toolCall(from: call))

      case .functionResponse(let response):
        if !parts.isEmpty || !toolCalls.isEmpty {
          results.append(
            message(
              role: normalizedRole(content.role),
              parts: parts,
              toolCalls: toolCalls
            )
          )
          parts = []
          toolCalls = []
        }
        results.append(toolResultMessage(from: response))

      case .executableCode, .codeExecutionResult, .unrecognized, .none:
        continue
      }
    }

    let hasToolCalls = !toolCalls.isEmpty
    if !parts.isEmpty || hasToolCalls || results.isEmpty {
      results.insert(
        message(
          role: normalizedRole(content.role),
          parts: parts,
          toolCalls: toolCalls
        ),
        at: 0
      )
    }

    return results
  }

  /// Builds a message with explicit parts.
  ///
  /// Text-only content is rendered as a bare string, matching the common case on the wire; anything
  /// carrying media keeps the typed part array.
  static func message(
    role: String,
    parts: [OrcaRouterChatCompletionRequest.ContentPart],
    toolCalls: [OrcaRouterChatCompletionRequest.ToolCall]
  ) -> OrcaRouterChatCompletionRequest.Message {
    let contentValue: OrcaRouterChatCompletionRequest.Content?
    if parts.isEmpty {
      contentValue = nil
    } else if parts.count == 1, parts[0].type == "text" {
      contentValue = .text(parts[0].text ?? "")
    } else {
      contentValue = .parts(parts)
    }
    return OrcaRouterChatCompletionRequest.Message(
      role: role,
      content: contentValue,
      toolCalls: toolCalls.isEmpty ? nil : toolCalls
    )
  }

  /// Maps the SDK's role string onto the OpenAI role set.
  ///
  /// - Parameter role: The role as it appears in the SDK request.
  package static func normalizedRole(_ role: String?) -> String {
    switch role?.lowercased() {
    case "model", "assistant": return "assistant"
    case "system": return "system"
    case "tool", "function": return "tool"
    default: return "user"
    }
  }

  /// Renders all text parts of a content as one string.
  static func textOnly(_ content: Content) -> String {
    (content.parts ?? []).compactMap { part in
      if case .text(let value) = part.data { return value }
      return nil
    }.joined()
  }

  /// Creates a content part for an inline blob, or `nil` for a modality the wire format cannot
  /// carry.
  static func mediaPart(from blob: Blob) -> OrcaRouterChatCompletionRequest.ContentPart? {
    let mimeType = blob.mimeType.lowercased()
    let base64 = blob.data.base64EncodedString()
    if mimeType.hasPrefix("image/") {
      return OrcaRouterChatCompletionRequest.ContentPart(
        type: "image_url",
        text: nil,
        imageURL: OrcaRouterChatCompletionRequest.ImageURL(
          url: "data:\(blob.mimeType);base64,\(base64)"
        ),
        inputAudio: nil
      )
    }
    if mimeType.hasPrefix("audio/") {
      return OrcaRouterChatCompletionRequest.ContentPart(
        type: "input_audio",
        text: nil,
        imageURL: nil,
        inputAudio: OrcaRouterChatCompletionRequest.InputAudio(
          data: base64,
          format: audioFormat(from: mimeType)
        )
      )
    }
    return nil
  }

  /// Creates a content part for a file reference.
  static func mediaPart(from file: FileData) -> OrcaRouterChatCompletionRequest.ContentPart? {
    let mimeType = file.mimeType.lowercased()
    guard mimeType.hasPrefix("image/") else { return nil }
    return OrcaRouterChatCompletionRequest.ContentPart(
      type: "image_url",
      text: nil,
      imageURL: OrcaRouterChatCompletionRequest.ImageURL(url: file.fileUri),
      inputAudio: nil
    )
  }

  /// Maps a MIME type onto the short audio format name the wire format expects.
  static func audioFormat(from mimeType: String) -> String {
    switch mimeType {
    case "audio/mpeg", "audio/mp3": return "mp3"
    case "audio/wav", "audio/x-wav", "audio/wave": return "wav"
    case "audio/flac", "audio/x-flac": return "flac"
    case "audio/ogg": return "ogg"
    case "audio/webm": return "webm"
    case "audio/mp4", "audio/m4a": return "m4a"
    default:
      return mimeType.split(separator: "/").last.map(String.init) ?? "wav"
    }
  }

  /// Converts the SDK's function declarations into OpenAI tool definitions.
  static func tools(
    from tools: [GeminiAPIDataModels.Tool]?
  ) -> [OrcaRouterChatCompletionRequest.Tool]? {
    guard let tools, !tools.isEmpty else { return nil }
    var declarations: [FunctionDeclaration] = []
    for tool in tools {
      if let functions = tool.functionDeclarations {
        declarations.append(contentsOf: functions)
      }
    }
    guard !declarations.isEmpty else { return nil }
    return declarations.map { declaration in
      OrcaRouterChatCompletionRequest.Tool(
        function: OrcaRouterChatCompletionRequest.Tool.Function(
          name: declaration.name,
          description: declaration.description,
          parameters: declaration.parametersJsonSchema ?? schemaValue(declaration.parameters)
        )
      )
    }
  }

  /// Converts a tool call into the wire format.
  static func toolCall(
    from call: FunctionCall
  ) -> OrcaRouterChatCompletionRequest.ToolCall {
    let arguments: String
    if let args = call.args, let data = try? JSONEncoder().encode(args) {
      arguments = String(decoding: data, as: UTF8.self)
    } else {
      arguments = "{}"
    }
    return OrcaRouterChatCompletionRequest.ToolCall(
      id: call.id,
      type: "function",
      function: OrcaRouterChatCompletionRequest.ToolCall.Function(
        name: call.name,
        arguments: arguments
      )
    )
  }

  /// Converts a function response into a `tool` message.
  static func toolResultMessage(
    from response: FunctionResponse
  ) -> OrcaRouterChatCompletionRequest.Message {
    let payload: String
    if let object = response.response,
      let data = try? JSONEncoder().encode(object)
    {
      payload = String(decoding: data, as: UTF8.self)
    } else {
      payload = "{}"
    }
    return OrcaRouterChatCompletionRequest.Message(
      role: "tool",
      content: .text(payload),
      toolCallID: response.id
    )
  }

  /// Converts the SDK tool configuration into a wire tool choice.
  static func toolChoice(from config: ToolConfig?) -> OrcaRouterChatCompletionRequest.ToolChoice? {
    guard let mode = config?.functionCallingConfig?.mode else { return nil }
    switch mode {
    case .auto, .validated, .unrecognized:
      return OrcaRouterChatCompletionRequest.ToolChoice(type: "auto")
    case .any:
      return OrcaRouterChatCompletionRequest.ToolChoice(type: "required")
    case .none:
      return OrcaRouterChatCompletionRequest.ToolChoice(type: "none")
    }
  }

  /// Converts the SDK's generation configuration into a wire response format.
  static func responseFormat(
    from config: GenerationConfig?
  ) -> OrcaRouterChatCompletionRequest.ResponseFormat? {
    if let jsonSchema = config?.responseJsonSchema {
      return OrcaRouterChatCompletionRequest.ResponseFormat(
        type: "json_schema",
        jsonSchema: jsonSchema
      )
    }
    if let mimeType = config?.responseMimeType?.lowercased(),
      mimeType == "application/json"
    {
      return OrcaRouterChatCompletionRequest.ResponseFormat(type: "json_object")
    }
    return nil
  }

  /// Converts a schema into a JSON value the wire format can carry.
  static func schemaValue(_ schema: Schema?) -> JSONValue? {
    guard let schema, let data = try? JSONEncoder().encode(schema) else { return nil }
    return try? JSONDecoder().decode(JSONValue.self, from: data)
  }
}

// MARK: - Response Translation

/// Translates OrcaRouter's OpenAI-compatible responses back into the SDK's Gemini-shaped models.
package enum OrcaRouterResponseTranslator {
  /// Converts a completion chunk into a generate-content response.
  ///
  /// - Parameters:
  ///   - chunk: The decoded wire chunk.
  ///   - responseID: The completion identifier, when one is present.
  /// - Returns: The SDK response, or `nil` when the chunk carries nothing worth yielding (a
  ///   usage-only final chunk is surfaced, so it is not skipped).
  package static func generateContentResponse(
    from chunk: OrcaRouterChatCompletionChunk,
    responseID: String? = nil
  ) -> GenerateContentResponse? {
    var candidates: [Candidate] = []
    for choice in chunk.choices ?? [] {
      let delta = choice.delta
      var parts: [Part] = []

      if let reasoning = delta?.reasoningContent, !reasoning.isEmpty {
        parts.append(Part(data: .text(reasoning), thought: true))
      }
      if let text = delta?.content, !text.isEmpty {
        parts.append(Part(data: .text(text)))
      }
      for call in delta?.toolCalls ?? [] {
        parts.append(
          Part(
            data: .functionCall(
              FunctionCall(
                id: call.id,
                name: call.function?.name ?? "",
                args: decodeArguments(call.function?.arguments)
              )
            )
          )
        )
      }

      let content = parts.isEmpty ? nil : Content(parts: parts, role: "model")
      candidates.append(
        Candidate(
          index: choice.index,
          content: content,
          finishReason: choice.finishReason.flatMap { Candidate.FinishReason(openAIValue: $0) }
        )
      )
    }

    if candidates.isEmpty, chunk.usage == nil { return nil }

    return GenerateContentResponse(
      candidates: candidates.isEmpty ? nil : candidates,
      usageMetadata: chunk.usage.map { usageMetadata(from: $0) },
      modelVersion: chunk.model,
      responseId: responseID ?? chunk.id
    )
  }

  /// Converts a usage block into the SDK's usage metadata.
  package static func usageMetadata(from usage: OrcaRouterUsage) -> UsageMetadata {
    UsageMetadata(
      promptTokenCount: usage.promptTokens,
      candidatesTokenCount: usage.completionTokens,
      thoughtsTokenCount: usage.completionTokensDetails?.reasoningTokens,
      totalTokenCount: usage.totalTokens
    )
  }

  /// Converts a non-streaming completion into a generate-content response.
  package static func generateContentResponse(
    from completion: OrcaRouterChatCompletion
  ) -> GenerateContentResponse {
    var candidates: [Candidate] = []
    for choice in completion.choices ?? [] {
      let message = choice.message
      var parts: [Part] = []
      if let reasoning = message?.reasoningContent, !reasoning.isEmpty {
        parts.append(Part(data: .text(reasoning), thought: true))
      }
      if let text = message?.content, !text.isEmpty {
        parts.append(Part(data: .text(text)))
      }
      for call in message?.toolCalls ?? [] {
        parts.append(
          Part(
            data: .functionCall(
              FunctionCall(
                id: call.id,
                name: call.function?.name ?? "",
                args: decodeArguments(call.function?.arguments)
              )
            )
          )
        )
      }
      candidates.append(
        Candidate(
          index: choice.index,
          content: parts.isEmpty ? nil : Content(parts: parts, role: "model"),
          finishReason: choice.finishReason.flatMap { Candidate.FinishReason(openAIValue: $0) }
        )
      )
    }

    return GenerateContentResponse(
      candidates: candidates.isEmpty ? nil : candidates,
      usageMetadata: completion.usage.map { usageMetadata(from: $0) },
      modelVersion: completion.model,
      responseId: completion.id
    )
  }

  /// Converts a usage block into a token count response.
  package static func countTokensResponse(from usage: OrcaRouterUsage) -> CountTokensResponse {
    CountTokensResponse(
      totalTokens: usage.totalTokens ?? usage.promptTokens,
      cachedContentTokenCount: usage.promptTokensDetails?.cachedTokens
    )
  }

  /// Decodes tool-call arguments from their JSON string form.
  static func decodeArguments(_ arguments: String?) -> JSONObject? {
    guard let arguments, !arguments.isEmpty, let data = arguments.data(using: .utf8) else {
      return nil
    }
    return try? JSONDecoder().decode(JSONObject.self, from: data)
  }
}

// MARK: - Wire Responses

/// A streamed completion chunk.
package struct OrcaRouterChatCompletionChunk: Decodable, Sendable {
  /// A single streamed choice.
  package struct Choice: Decodable, Sendable {
    /// The position of the choice.
    package let index: Int?
    /// The incremental content.
    package let delta: Delta?
    /// The reason the model stopped, on the final chunk.
    package let finishReason: String?

    enum CodingKeys: String, CodingKey {
      case index
      case delta
      case finishReason = "finish_reason"
    }
  }

  /// The incremental content of one chunk.
  package struct Delta: Decodable, Sendable {
    /// Text content.
    package let content: String?
    /// Reasoning content, when the model exposes it.
    package let reasoningContent: String?
    /// Tool call fragments.
    package let toolCalls: [ToolCallDelta]?

    enum CodingKeys: String, CodingKey {
      case content
      case reasoningContent = "reasoning_content"
      case toolCalls = "tool_calls"
    }
  }

  /// A streamed tool call fragment.
  package struct ToolCallDelta: Decodable, Sendable {
    /// A function invocation fragment.
    package struct Function: Decodable, Sendable {
      package let name: String?
      package let arguments: String?
    }

    package let index: Int?
    package let id: String?
    package let function: Function?
  }

  package let id: String?
  package let model: String?
  package let choices: [Choice]?
  package let usage: OrcaRouterUsage?
}

/// A non-streamed completion.
package struct OrcaRouterChatCompletion: Decodable, Sendable {
  /// A single choice.
  package struct Choice: Decodable, Sendable {
    package let index: Int?
    package let message: Message?
    package let finishReason: String?

    enum CodingKeys: String, CodingKey {
      case index
      case message
      case finishReason = "finish_reason"
    }
  }

  /// The assistant's reply.
  package struct Message: Decodable, Sendable {
    package let role: String?
    package let content: String?
    package let reasoningContent: String?
    package let toolCalls: [OrcaRouterChatCompletionChunk.ToolCallDelta]?

    enum CodingKeys: String, CodingKey {
      case role
      case content
      case reasoningContent = "reasoning_content"
      case toolCalls = "tool_calls"
    }
  }

  package let id: String?
  package let model: String?
  package let choices: [Choice]?
  package let usage: OrcaRouterUsage?
}

/// Token accounting reported by the origin.
package struct OrcaRouterUsage: Decodable, Sendable {
  /// Cached-prompt detail.
  package struct PromptDetails: Decodable, Sendable {
    package let cachedTokens: Int?

    enum CodingKeys: String, CodingKey {
      case cachedTokens = "cached_tokens"
    }
  }

  /// Completion detail.
  package struct CompletionDetails: Decodable, Sendable {
    package let reasoningTokens: Int?

    enum CodingKeys: String, CodingKey {
      case reasoningTokens = "reasoning_tokens"
    }
  }

  package let promptTokens: Int?
  package let completionTokens: Int?
  package let totalTokens: Int?
  package let promptTokensDetails: PromptDetails?
  package let completionTokensDetails: CompletionDetails?

  enum CodingKeys: String, CodingKey {
    case promptTokens = "prompt_tokens"
    case completionTokens = "completion_tokens"
    case totalTokens = "total_tokens"
    case promptTokensDetails = "prompt_tokens_details"
    case completionTokensDetails = "completion_tokens_details"
  }
}

extension Candidate.FinishReason {
  /// Maps an OpenAI `finish_reason` onto the SDK's finish reason.
  ///
  /// - Parameter openAIValue: The wire value.
  init(openAIValue: String) {
    switch openAIValue {
    case "stop": self = .stop
    case "length": self = .maxTokens
    case "tool_calls", "function_call": self = .stop
    case "content_filter": self = .safety
    default: self = .other
    }
  }
}
