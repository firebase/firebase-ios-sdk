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

extension GenerateContentAPI {
  /// An internal data model for `Part`.
  ///
  /// ### Gemini Developer API
  ///
  /// Type: `GoogleAiGenerativelanguageV1betaPart`
  ///
  /// A datatype containing media that is part of a multi-part `Content` message.
  ///
  /// A `Part` consists of data which has an associated datatype. A `Part` can only
  /// contain one of the accepted types in `Part.data`.
  ///
  /// A `Part` must have a fixed IANA MIME type identifying the type and subtype
  /// of the media if the `inline_data` field is filled with raw bytes.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// Type: `GoogleCloudAiplatformV1beta1Part`
  ///
  /// A datatype containing media that is part of a multi-part
  /// Content message.
  ///
  /// A `Part` consists of data which has an associated datatype. A `Part` can only
  /// contain one of the accepted types in `Part.data`.
  ///
  /// For media types that are not text, `Part` must have a fixed IANA MIME type
  /// identifying the type and subtype of the media if `inline_data` or
  /// `file_data` field is filled with raw bytes.
  struct Part: Codable, Sendable, Equatable, Hashable {
    /// Server-side tool call. This field is populated when the model
    ///
    /// ### Gemini Developer API
    ///
    /// Server-side tool call. This field is populated when the model
    /// predicts a tool invocation that should be executed on the server.
    /// The client is expected to echo this message back to the API.
    ///
    /// ### Gemini Enterprise Agent Platform
    ///
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    let toolCall: ToolCall?

    /// The output from a server-side `ToolCall` execution. This field is
    ///
    /// ### Gemini Developer API
    ///
    /// The output from a server-side `ToolCall` execution. This field is
    /// populated by the client with the results of executing the
    /// corresponding `ToolCall`.
    ///
    /// ### Gemini Enterprise Agent Platform
    ///
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    let toolResponse: ToolResponse?

    /// Optional. Indicates if the part is thought from the model.
    ///
    /// ### Gemini Developer API
    ///
    /// Optional. Indicates if the part is thought from the model.
    ///
    /// ### Gemini Enterprise Agent Platform
    ///
    /// Optional. Indicates whether the `part` represents the model's thought
    /// process or reasoning.
    let thought: Bool?

    /// Optional. An opaque signature for the thought so it can be reused in subsequent
    ///
    /// ### Gemini Developer API
    ///
    /// Optional. An opaque signature for the thought so it can be reused in subsequent
    /// requests.
    ///
    /// ### Gemini Enterprise Agent Platform
    ///
    /// Optional. An opaque signature for the thought so it can be reused in
    /// subsequent requests.
    let thoughtSignature: Data?

    /// Custom metadata associated with the Part.
    ///
    /// ### Gemini Developer API
    ///
    /// Custom metadata associated with the Part.
    /// Agents using genai.Part as content representation may need to keep track
    /// of the additional information. For example it can be name of a file/source
    /// from which the Part originates or a way to multiplex multiple Part streams.
    ///
    /// ### Gemini Enterprise Agent Platform
    ///
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    let partMetadata: [String: ProtobufValue]?

    /// Optional. Media resolution for the input media.
    ///
    /// ### Gemini Developer API
    ///
    /// Optional. Media resolution for the input media.
    ///
    /// ### Gemini Enterprise Agent Platform
    ///
    /// per part media resolution.
    /// Media resolution for the input media.
    let mediaResolution: Part.MediaResolution?

    enum PartData: Sendable, Equatable, Hashable {
      case text(String)
      case inlineData(Blob)
      case functionCall(FunctionCall)
      case functionResponse(FunctionResponse)
      case fileData(FileData)
      case executableCode(ExecutableCode)
      case codeExecutionResult(CodeExecutionResult)
      case unrecognized(ProtobufStruct)
    }

    let data: PartData?

    /// Creates a new `Part`.
    ///
    /// - Parameters:
    ///   - toolCall: Server-side tool call. This field is populated when the model (Gemini
    /// Developer API only). For more details, see ``toolCall``.
    ///   - toolResponse: The output from a server-side `ToolCall` execution. This field is (Gemini
    /// Developer API only). For more details, see ``toolResponse``.
    ///   - thought: Optional. Indicates if the part is thought from the model. (behavior varies by
    /// backend). For more details, see ``thought``.
    ///   - thoughtSignature: Optional. An opaque signature for the thought so it can be reused in
    /// subsequent (behavior varies by backend). For more details, see ``thoughtSignature``.
    ///   - partMetadata: Custom metadata associated with the Part. (Gemini Developer API only). For
    /// more details, see ``partMetadata``.
    ///   - mediaResolution: Optional. Media resolution for the input media. (behavior varies by
    /// backend). For more details, see ``mediaResolution``.
    ///   - data: One of the oneof data variants.
    init(data: PartData? = nil,
         toolCall: ToolCall? = nil,
         toolResponse: ToolResponse? = nil,
         thought: Bool? = nil,
         thoughtSignature: Data? = nil,
         partMetadata: [String: ProtobufValue]? = nil,
         mediaResolution: Part.MediaResolution? = nil) {
      self.data = data
      self.toolCall = toolCall
      self.toolResponse = toolResponse
      self.thought = thought
      self.thoughtSignature = thoughtSignature
      self.partMetadata = partMetadata
      self.mediaResolution = mediaResolution
    }

    enum CodingKeys: String, CodingKey {
      case toolCall
      case toolResponse
      case thought
      case thoughtSignature
      case partMetadata
      case mediaResolution
      case text
      case inlineData
      case functionCall
      case functionResponse
      case fileData
      case executableCode
      case codeExecutionResult
    }

    private struct DynamicCodingKey: CodingKey {
      var stringValue: String
      var intValue: Int? { nil }
      init?(stringValue: String) { self.stringValue = stringValue }
      init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      toolCall = try container.decodeIfPresent(ToolCall.self, forKey: .toolCall)
      toolResponse = try container.decodeIfPresent(ToolResponse.self, forKey: .toolResponse)
      thought = try container.decodeIfPresent(Bool.self, forKey: .thought)
      thoughtSignature = try container.decodeIfPresent(Data.self, forKey: .thoughtSignature)
      partMetadata = try container.decodeIfPresent(
        [String: ProtobufValue].self,
        forKey: .partMetadata
      )
      mediaResolution = try container.decodeIfPresent(
        Part.MediaResolution.self,
        forKey: .mediaResolution
      )

      if false {
        data = nil
      } else if let text = try container.decodeIfPresent(String.self, forKey: .text) {
        data = .text(text)
      } else if let inlineData = try container.decodeIfPresent(Blob.self, forKey: .inlineData) {
        data = .inlineData(inlineData)
      } else if let functionCall = try container.decodeIfPresent(
        FunctionCall.self,
        forKey: .functionCall
      ) {
        data = .functionCall(functionCall)
      } else if let functionResponse = try container.decodeIfPresent(
        FunctionResponse.self,
        forKey: .functionResponse
      ) {
        data = .functionResponse(functionResponse)
      } else if let fileData = try container.decodeIfPresent(FileData.self, forKey: .fileData) {
        data = .fileData(fileData)
      } else if let executableCode = try container.decodeIfPresent(
        ExecutableCode.self,
        forKey: .executableCode
      ) {
        data = .executableCode(executableCode)
      } else if let codeExecutionResult = try container.decodeIfPresent(
        CodeExecutionResult.self,
        forKey: .codeExecutionResult
      ) {
        data = .codeExecutionResult(codeExecutionResult)
      } else {
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var unrecognizedFields = ProtobufStruct()
        for key in dynamicContainer.allKeys {
          if CodingKeys(stringValue: key.stringValue) == nil,
             let value = try? dynamicContainer.decode(ProtobufValue.self, forKey: key) {
            unrecognizedFields[key.stringValue] = value
          }
        }
        data = unrecognizedFields.isEmpty ? nil : .unrecognized(unrecognizedFields)
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encodeIfPresent(toolCall, forKey: .toolCall)
      try container.encodeIfPresent(toolResponse, forKey: .toolResponse)
      try container.encodeIfPresent(thought, forKey: .thought)
      try container.encodeIfPresent(thoughtSignature, forKey: .thoughtSignature)
      try container.encodeIfPresent(partMetadata, forKey: .partMetadata)
      try container.encodeIfPresent(mediaResolution, forKey: .mediaResolution)

      switch data {
      case .none: break
      case let .text(val): try container.encode(val, forKey: .text)
      case let .inlineData(val): try container.encode(val, forKey: .inlineData)
      case let .functionCall(val): try container.encode(val, forKey: .functionCall)
      case let .functionResponse(val): try container.encode(val, forKey: .functionResponse)
      case let .fileData(val): try container.encode(val, forKey: .fileData)
      case let .executableCode(val): try container.encode(val, forKey: .executableCode)
      case let .codeExecutionResult(val): try container.encode(val, forKey: .codeExecutionResult)
      case let .unrecognized(unrecognizedFields):
        var dynamicContainer = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in unrecognizedFields {
          if let codingKey = DynamicCodingKey(stringValue: key) {
            try dynamicContainer.encode(value, forKey: codingKey)
          }
        }
      }
    }
  }
}
