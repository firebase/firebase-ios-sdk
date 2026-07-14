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
package import InternalSharedDataModels


extension GeminiDataModels {
  /// A datatype containing media that is part of a multi-part `Content` message. A `Part` consists of data which has an associated datatype. A `Part` can only contain one of the accepted types in `Part.data`. A `Part` must have a fixed IANA MIME type identifying the type and subtype of the media if the `inline_data` field is filled with raw bytes.
  /// 
  /// Variant:
  /// A datatype containing media that is part of a multi-part Content message. A `Part` consists of data which has an associated datatype. A `Part` can only contain one of the accepted types in `Part.data`. For media types that are not text, `Part` must have a fixed IANA MIME type identifying the type and subtype of the media if `inline_data` or `file_data` field is filled with raw bytes.
  package struct Part: Codable, Sendable, Equatable, Hashable {
    /// A predicted `FunctionCall` returned from the model that contains a string representing the `FunctionDeclaration.name` with the arguments and their values.
    /// 
    /// Variant:
    /// Optional. A predicted function call returned from the model. This contains the name of the function to call and the arguments to pass to the function.
    package let functionCall: FunctionCall?
    
    /// Optional. Indicates if the part is thought from the model.
    /// 
    /// Variant:
    /// Optional. Indicates whether the `part` represents the model's thought process or reasoning.
    package let thought: Bool?
    
    /// Optional. Media resolution for the input media.
    /// 
    /// Variant:
    /// per part media resolution. Media resolution for the input media.
    package let mediaResolution: GenerationConfig.MediaResolution?
    
    /// Optional. Video metadata. The metadata should only be specified while the video data is presented in inline_data or file_data.
    @available(*, deprecated)
    package let videoMetadata: VideoMetadata?
    
    /// Result of executing the `ExecutableCode`.
    /// 
    /// Variant:
    /// Optional. The result of executing the ExecutableCode.
    package let codeExecutionResult: CodeExecutionResult?
    
    /// Optional. An opaque signature for the thought so it can be reused in subsequent requests.
    package let thoughtSignature: String?
    
    /// The output from a server-side `ToolCall` execution. This field is populated by the client with the results of executing the corresponding `ToolCall`.
    /// 
    /// > Important: `toolResponse` is only available in the Gemini Developer API.
    package let toolResponse: ToolResponse?
    
    /// Inline media bytes.
    /// 
    /// Variant:
    /// Optional. The inline data content of the part. This can be used to include images, audio, or video in a request.
    package let inlineData: Blob?
    
    /// Inline text.
    /// 
    /// Variant:
    /// Optional. The text content of the part. When sent from the VSCode Gemini Code Assist extension, references to @mentioned items will be converted to markdown boldface text. For example `@my-repo` will be converted to and sent as `**my-repo**` by the IDE agent.
    package let text: String?
    
    /// Custom metadata associated with the Part. Agents using genai.Part as content representation may need to keep track of the additional information. For example it can be name of a file/source from which the Part originates or a way to multiplex multiple Part streams.
    /// 
    /// > Important: `partMetadata` is only available in the Gemini Developer API.
    package let partMetadata: [String: JSONValue]?
    
    /// The result output of a `FunctionCall` that contains a string representing the `FunctionDeclaration.name` and a structured JSON object containing any output from the function is used as context to the model.
    /// 
    /// Variant:
    /// Optional. The result of a function call. This is used to provide the model with the result of a function call that it predicted.
    package let functionResponse: FunctionResponse?
    
    /// URI based data.
    /// 
    /// Variant:
    /// Optional. The URI-based data of the part. This can be used to include files from Google Cloud Storage.
    package let fileData: FileData?
    
    /// Server-side tool call. This field is populated when the model predicts a tool invocation that should be executed on the server. The client is expected to echo this message back to the API.
    /// 
    /// > Important: `toolCall` is only available in the Gemini Developer API.
    package let toolCall: ToolCall?
    
    /// Code generated by the model that is meant to be executed.
    /// 
    /// Variant:
    /// Optional. Code generated by the model that is intended to be executed.
    package let executableCode: ExecutableCode?
    
    /// Creates a new `Part`.
    package init(
      functionCall: FunctionCall? = nil,
      thought: Bool? = nil,
      mediaResolution: GenerationConfig.MediaResolution? = nil,
      videoMetadata: VideoMetadata? = nil,
      codeExecutionResult: CodeExecutionResult? = nil,
      thoughtSignature: String? = nil,
      toolResponse: ToolResponse? = nil,
      inlineData: Blob? = nil,
      text: String? = nil,
      partMetadata: [String: JSONValue]? = nil,
      functionResponse: FunctionResponse? = nil,
      fileData: FileData? = nil,
      toolCall: ToolCall? = nil,
      executableCode: ExecutableCode? = nil
    ) {
      self.functionCall = functionCall
      self.thought = thought
      self.mediaResolution = mediaResolution
      self.videoMetadata = videoMetadata
      self.codeExecutionResult = codeExecutionResult
      self.thoughtSignature = thoughtSignature
      self.toolResponse = toolResponse
      self.inlineData = inlineData
      self.text = text
      self.partMetadata = partMetadata
      self.functionResponse = functionResponse
      self.fileData = fileData
      self.toolCall = toolCall
      self.executableCode = executableCode
    }
    enum CodingKeys: String, CodingKey {
      case functionCall = "functionCall"
      case thought = "thought"
      case mediaResolution = "mediaResolution"
      case videoMetadata = "videoMetadata"
      case codeExecutionResult = "codeExecutionResult"
      case thoughtSignature = "thoughtSignature"
      case toolResponse = "toolResponse"
      case inlineData = "inlineData"
      case text = "text"
      case partMetadata = "partMetadata"
      case functionResponse = "functionResponse"
      case fileData = "fileData"
      case toolCall = "toolCall"
      case executableCode = "executableCode"
    }
  }
}