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
  /// The output from a server-side `ToolCall` execution. This message contains the results of a tool invocation that was initiated by a `ToolCall` from the model. The client should pass this `ToolResponse` back to the API in a subsequent turn within a `Content` message, along with the corresponding `ToolCall`.
  /// 
  /// > Important: This type is only available in the Gemini Developer API.
  package struct ToolResponse: Codable, Sendable, Equatable, Hashable {
    /// Optional. The identifier of the tool call this response is for.
    /// 
    /// > Important: `id` is only available in the Gemini Developer API.
    package let id: String?
    
    /// Optional. The tool response.
    /// 
    /// > Important: `response` is only available in the Gemini Developer API.
    package let response: [String: JSONValue]?
    
    /// Required. The type of tool that was called, matching the `tool_type` in the corresponding `ToolCall`.
    /// 
    /// > Important: `toolType` is only available in the Gemini Developer API.
    package let toolType: ToolType?
    
    /// Creates a new `ToolResponse`.
    package init(
      id: String? = nil,
      response: [String: JSONValue]? = nil,
      toolType: ToolType? = nil
    ) {
      self.id = id
      self.response = response
      self.toolType = toolType
    }
    enum CodingKeys: String, CodingKey {
      case id = "id"
      case response = "response"
      case toolType = "toolType"
    }
  }
}