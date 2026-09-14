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

package import GeminiSharedDataModels

/// An internal data model for `StepDeltaData`.
package enum StepDeltaData: Codable, Sendable, Equatable, Hashable {

  /// An internal data model for `ArgumentsDelta`.
  case argumentsDelta(ArgumentsDelta)

  /// An internal data model for `AudioDelta`.
  case audioDelta(AudioDelta)

  /// An internal data model for `CodeExecutionCallDelta`.
  case codeExecutionCallDelta(CodeExecutionCallDelta)

  /// An internal data model for `CodeExecutionResultDelta`.
  case codeExecutionResultDelta(CodeExecutionResultDelta)

  /// An internal data model for `DocumentDelta`.
  case documentDelta(DocumentDelta)

  /// An internal data model for `FileSearchCallDelta`.
  case fileSearchCallDelta(FileSearchCallDelta)

  /// An internal data model for `FileSearchResultDelta`.
  case fileSearchResultDelta(FileSearchResultDelta)

  /// An internal data model for `FunctionResultDelta`.
  case functionResultDelta(FunctionResultDelta)

  /// An internal data model for `GoogleMapsCallDelta`.
  case googleMapsCallDelta(GoogleMapsCallDelta)

  /// An internal data model for `GoogleMapsResultDelta`.
  case googleMapsResultDelta(GoogleMapsResultDelta)

  /// An internal data model for `GoogleSearchCallDelta`.
  case googleSearchCallDelta(GoogleSearchCallDelta)

  /// An internal data model for `GoogleSearchResultDelta`.
  case googleSearchResultDelta(GoogleSearchResultDelta)

  /// An internal data model for `ImageDelta`.
  case imageDelta(ImageDelta)

  /// An internal data model for `MCPServerToolCallDelta`.
  case mCPServerToolCallDelta(MCPServerToolCallDelta)

  /// An internal data model for `MCPServerToolResultDelta`.
  case mCPServerToolResultDelta(MCPServerToolResultDelta)

  /// Streaming delta for a server-initiated media processing step.
  case processingCallDelta(ProcessingCallDelta)

  /// Streaming delta for the result of a server-initiated media processing step.
  case processingResultDelta(ProcessingResultDelta)

  /// An internal data model for `TextAnnotationDelta`.
  case textAnnotationDelta(TextAnnotationDelta)

  /// An internal data model for `TextDelta`.
  case textDelta(TextDelta)

  /// An internal data model for `ThoughtSignatureDelta`.
  case thoughtSignatureDelta(ThoughtSignatureDelta)

  /// An internal data model for `ThoughtSummaryDelta`.
  case thoughtSummaryDelta(ThoughtSummaryDelta)

  /// An internal data model for `URLContextCallDelta`.
  case uRLContextCallDelta(URLContextCallDelta)

  /// An internal data model for `URLContextResultDelta`.
  case uRLContextResultDelta(URLContextResultDelta)

  /// An internal data model for `VideoDelta`.
  case videoDelta(VideoDelta)

  /// Unrecognized case.
  case unrecognized(JSONValue)

  private enum CodingKeys: String, CodingKey {
    case discriminator = "type"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let discValue = try container.decode(String.self, forKey: .discriminator)
    switch discValue {
    case "arguments_delta":
      let val = try ArgumentsDelta(from: decoder)
      self = .argumentsDelta(val)
    case "audio":
      let val = try AudioDelta(from: decoder)
      self = .audioDelta(val)
    case "code_execution_call":
      let val = try CodeExecutionCallDelta(from: decoder)
      self = .codeExecutionCallDelta(val)
    case "code_execution_result":
      let val = try CodeExecutionResultDelta(from: decoder)
      self = .codeExecutionResultDelta(val)
    case "document":
      let val = try DocumentDelta(from: decoder)
      self = .documentDelta(val)
    case "file_search_call":
      let val = try FileSearchCallDelta(from: decoder)
      self = .fileSearchCallDelta(val)
    case "file_search_result":
      let val = try FileSearchResultDelta(from: decoder)
      self = .fileSearchResultDelta(val)
    case "function_result":
      let val = try FunctionResultDelta(from: decoder)
      self = .functionResultDelta(val)
    case "google_maps_call":
      let val = try GoogleMapsCallDelta(from: decoder)
      self = .googleMapsCallDelta(val)
    case "google_maps_result":
      let val = try GoogleMapsResultDelta(from: decoder)
      self = .googleMapsResultDelta(val)
    case "google_search_call":
      let val = try GoogleSearchCallDelta(from: decoder)
      self = .googleSearchCallDelta(val)
    case "google_search_result":
      let val = try GoogleSearchResultDelta(from: decoder)
      self = .googleSearchResultDelta(val)
    case "image":
      let val = try ImageDelta(from: decoder)
      self = .imageDelta(val)
    case "mcp_server_tool_call":
      let val = try MCPServerToolCallDelta(from: decoder)
      self = .mCPServerToolCallDelta(val)
    case "mcp_server_tool_result":
      let val = try MCPServerToolResultDelta(from: decoder)
      self = .mCPServerToolResultDelta(val)
    case "processing_call":
      let val = try ProcessingCallDelta(from: decoder)
      self = .processingCallDelta(val)
    case "processing_result":
      let val = try ProcessingResultDelta(from: decoder)
      self = .processingResultDelta(val)
    case "text_annotation_delta":
      let val = try TextAnnotationDelta(from: decoder)
      self = .textAnnotationDelta(val)
    case "text":
      let val = try TextDelta(from: decoder)
      self = .textDelta(val)
    case "thought_signature":
      let val = try ThoughtSignatureDelta(from: decoder)
      self = .thoughtSignatureDelta(val)
    case "thought_summary":
      let val = try ThoughtSummaryDelta(from: decoder)
      self = .thoughtSummaryDelta(val)
    case "url_context_call":
      let val = try URLContextCallDelta(from: decoder)
      self = .uRLContextCallDelta(val)
    case "url_context_result":
      let val = try URLContextResultDelta(from: decoder)
      self = .uRLContextResultDelta(val)
    case "video":
      let val = try VideoDelta(from: decoder)
      self = .videoDelta(val)
    default:
      let val = try JSONValue(from: decoder)
      self = .unrecognized(val)
    }
  }

  package func encode(to encoder: any Encoder) throws {
    switch self {
    case .argumentsDelta(let val):
      try val.encode(to: encoder)
    case .audioDelta(let val):
      try val.encode(to: encoder)
    case .codeExecutionCallDelta(let val):
      try val.encode(to: encoder)
    case .codeExecutionResultDelta(let val):
      try val.encode(to: encoder)
    case .documentDelta(let val):
      try val.encode(to: encoder)
    case .fileSearchCallDelta(let val):
      try val.encode(to: encoder)
    case .fileSearchResultDelta(let val):
      try val.encode(to: encoder)
    case .functionResultDelta(let val):
      try val.encode(to: encoder)
    case .googleMapsCallDelta(let val):
      try val.encode(to: encoder)
    case .googleMapsResultDelta(let val):
      try val.encode(to: encoder)
    case .googleSearchCallDelta(let val):
      try val.encode(to: encoder)
    case .googleSearchResultDelta(let val):
      try val.encode(to: encoder)
    case .imageDelta(let val):
      try val.encode(to: encoder)
    case .mCPServerToolCallDelta(let val):
      try val.encode(to: encoder)
    case .mCPServerToolResultDelta(let val):
      try val.encode(to: encoder)
    case .processingCallDelta(let val):
      try val.encode(to: encoder)
    case .processingResultDelta(let val):
      try val.encode(to: encoder)
    case .textAnnotationDelta(let val):
      try val.encode(to: encoder)
    case .textDelta(let val):
      try val.encode(to: encoder)
    case .thoughtSignatureDelta(let val):
      try val.encode(to: encoder)
    case .thoughtSummaryDelta(let val):
      try val.encode(to: encoder)
    case .uRLContextCallDelta(let val):
      try val.encode(to: encoder)
    case .uRLContextResultDelta(let val):
      try val.encode(to: encoder)
    case .videoDelta(let val):
      try val.encode(to: encoder)
    case .unrecognized(let val):
      try val.encode(to: encoder)
    }
  }
}
