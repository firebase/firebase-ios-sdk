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
  /// An internal data model for `ToolResponse`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaToolResponse`
  /// 
  /// The output from a server-side `ToolCall` execution. This message contains
  /// the results of a tool invocation that was initiated by a `ToolCall`
  /// from the model. The client should pass this `ToolResponse` back to the API
  /// in a subsequent turn within a `Content` message, along with the corresponding
  /// `ToolCall`.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct ToolResponse: Codable, Sendable, Equatable, Hashable {
    /// Optional. The identifier of the tool call this response is for.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The identifier of the tool call this response is for.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let id: String?
    
    /// Required. The type of tool that was called, matching the `tool_type` in the
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The type of tool that was called, matching the `tool_type` in the
    /// corresponding `ToolCall`.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let toolType: ToolType
    
    /// Optional. The tool response.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The tool response.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let response: [String: JSONValue]?
    

    /// Creates a new `ToolResponse`.
    ///
    /// - Parameters:
    ///   - id: Optional. The identifier of the tool call this response is for. (Gemini Developer API only). For more details, see ``id``.
    ///   - toolType: Required. The type of tool that was called, matching the `tool_type` in the (Gemini Developer API only). For more details, see ``toolType``.
    ///   - response: Optional. The tool response. (Gemini Developer API only). For more details, see ``response``.
    package init(
      id: String? = nil,
      toolType: ToolType,
      response: [String: JSONValue]? = nil
    ) {
      self.id = id
      self.toolType = toolType
      self.response = response
    }
    enum CodingKeys: String, CodingKey {
      case id = "id"
      case toolType = "toolType"
      case response = "response"
    }
  }
}