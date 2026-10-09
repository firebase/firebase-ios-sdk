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

/// A datatype containing media that is part of a multi-part Content message. A `Part` consists of
/// data which has an associated datatype. A `Part` can only contain one of the accepted types in
/// `Part.data`. For media types that are not text, `Part` must have a fixed IANA MIME type
/// identifying the type and subtype of the media if `inline_data` or `file_data` field is filled
/// with raw bytes.
package struct Part: Codable, Sendable, Equatable, Hashable, Buildable {
  /// Audio (input or output) transcription. This is only set when this `Part` contains audio data.
  package var audioTranscription: AudioTranscription?

  /// How the model processes this part's media for understanding. Only meaningful for video parts
  /// (`inline_data` or `file_data` with video mime). Non-video parts ignore this field.
  package var mediaProcessing: MediaProcessing?

  /// Per part media resolution. Media resolution for the input media.
  package var mediaResolution: Part.MediaResolution?

  /// Custom metadata associated with the Part. Agents using genai.Part as content representation
  /// may need to keep track of the additional information. For example it can be name of a
  /// file/source from which the Part originates or a way to multiplex multiple Part streams.
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package var partMetadata: JSONObject?

  /// Turn-level metadata for speech generation (e.g. Daikon speaker/style). May be set alongside
  /// `text` to attach speaker and style information to a text part.
  package var speechMetadata: SpeechMetadata?

  /// Indicates whether the `part` represents the model's thought process or reasoning.
  package var thought: Bool?

  /// An opaque signature for the thought so it can be reused in subsequent requests.
  package var thoughtSignature: String?

  /// Server-side tool call. This field is populated when the model predicts a tool invocation that
  /// should be executed on the server. The client is expected to echo this message back to the API.
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package var toolCall: ToolCall?

  /// The output from a server-side `ToolCall` execution. This field is populated by the client with
  /// the results of executing the corresponding `ToolCall`.
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package var toolResponse: ToolResponse?

  package enum PartData: Sendable, Equatable, Hashable {
    case codeExecutionResult(CodeExecutionResult)
    case executableCode(ExecutableCode)
    case fileData(FileData)
    case functionCall(FunctionCall)
    case functionResponse(FunctionResponse)
    case inlineData(Blob)
    case text(String)
    case unrecognized([String: JSONValue])
  }

  package var data: PartData?

  /// Initializes a new `Part`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case audioTranscription
    case mediaProcessing
    case mediaResolution
    case partMetadata
    case speechMetadata
    case thought
    case thoughtSignature
    case toolCall
    case toolResponse
    case codeExecutionResult
    case executableCode
    case fileData
    case functionCall
    case functionResponse
    case inlineData
    case text
  }

  private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.audioTranscription = try container.decodeIfPresent(
      AudioTranscription.self, forKey: .audioTranscription)
    self.mediaProcessing = try container.decodeIfPresent(
      MediaProcessing.self, forKey: .mediaProcessing)
    self.mediaResolution = try container.decodeIfPresent(
      Part.MediaResolution.self, forKey: .mediaResolution)
    self.partMetadata = try container.decodeIfPresent(JSONObject.self, forKey: .partMetadata)
    self.speechMetadata = try container.decodeIfPresent(
      SpeechMetadata.self, forKey: .speechMetadata)
    self.thought = try container.decodeIfPresent(Bool.self, forKey: .thought)
    self.thoughtSignature = try container.decodeIfPresent(String.self, forKey: .thoughtSignature)
    self.toolCall = try container.decodeIfPresent(ToolCall.self, forKey: .toolCall)
    self.toolResponse = try container.decodeIfPresent(ToolResponse.self, forKey: .toolResponse)

    if let codeExecutionResult = try container.decodeIfPresent(
      CodeExecutionResult.self, forKey: .codeExecutionResult)
    {
      self.data = .codeExecutionResult(codeExecutionResult)
    } else if let executableCode = try container.decodeIfPresent(
      ExecutableCode.self, forKey: .executableCode)
    {
      self.data = .executableCode(executableCode)
    } else if let fileData = try container.decodeIfPresent(FileData.self, forKey: .fileData) {
      self.data = .fileData(fileData)
    } else if let functionCall = try container.decodeIfPresent(
      FunctionCall.self, forKey: .functionCall)
    {
      self.data = .functionCall(functionCall)
    } else if let functionResponse = try container.decodeIfPresent(
      FunctionResponse.self, forKey: .functionResponse)
    {
      self.data = .functionResponse(functionResponse)
    } else if let inlineData = try container.decodeIfPresent(Blob.self, forKey: .inlineData) {
      self.data = .inlineData(inlineData)
    } else if let text = try container.decodeIfPresent(String.self, forKey: .text) {
      self.data = .text(text)
    } else {
      let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
      var unrecognizedFields = [String: JSONValue]()
      for key in dynamicContainer.allKeys {
        if CodingKeys(stringValue: key.stringValue) == nil,
          let value = try? dynamicContainer.decode(JSONValue.self, forKey: key)
        {
          unrecognizedFields[key.stringValue] = value
        }
      }
      self.data = unrecognizedFields.isEmpty ? nil : .unrecognized(unrecognizedFields)
    }
  }

  package func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(audioTranscription, forKey: .audioTranscription)
    try container.encodeIfPresent(mediaProcessing, forKey: .mediaProcessing)
    try container.encodeIfPresent(mediaResolution, forKey: .mediaResolution)
    try container.encodeIfPresent(partMetadata, forKey: .partMetadata)
    try container.encodeIfPresent(speechMetadata, forKey: .speechMetadata)
    try container.encodeIfPresent(thought, forKey: .thought)
    try container.encodeIfPresent(thoughtSignature, forKey: .thoughtSignature)
    try container.encodeIfPresent(toolCall, forKey: .toolCall)
    try container.encodeIfPresent(toolResponse, forKey: .toolResponse)

    switch data {
    case .none: break
    case .codeExecutionResult(let val): try container.encode(val, forKey: .codeExecutionResult)
    case .executableCode(let val): try container.encode(val, forKey: .executableCode)
    case .fileData(let val): try container.encode(val, forKey: .fileData)
    case .functionCall(let val): try container.encode(val, forKey: .functionCall)
    case .functionResponse(let val): try container.encode(val, forKey: .functionResponse)
    case .inlineData(let val): try container.encode(val, forKey: .inlineData)
    case .text(let val): try container.encode(val, forKey: .text)
    case .unrecognized(let unrecognizedFields):
      var dynamicContainer = encoder.container(keyedBy: DynamicCodingKey.self)
      for (key, value) in unrecognizedFields {
        if let codingKey = DynamicCodingKey(stringValue: key) {
          try dynamicContainer.encode(value, forKey: codingKey)
        }
      }
    }
  }
}
