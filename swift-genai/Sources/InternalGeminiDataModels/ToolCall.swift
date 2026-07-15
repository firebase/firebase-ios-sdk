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
  /// An internal data model for `ToolCall`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaToolCall`
  /// 
  /// A predicted server-side `ToolCall` returned from the model. This message
  /// contains information about a tool that the model wants to invoke.
  /// The client is NOT expected to execute this `ToolCall`. Instead, the
  /// client should pass this `ToolCall` back to the API in a subsequent turn
  /// within a `Content` message, along with the corresponding `ToolResponse`.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct ToolCall: Codable, Sendable, Equatable, Hashable {
    /// Optional. Unique identifier of the tool call.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Unique identifier of the tool call.
    /// The server returns the tool response with the matching `id`.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let id: String?
    
    /// Required. The type of tool that was called.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The type of tool that was called.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let toolType: ToolType
    
    /// Optional. The tool call arguments.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The tool call arguments.
    /// Example: {"arg1" : "value1", "arg2" : "value2" , ...}
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let args: [String: JSONValue]?
    

    /// Creates a new `ToolCall`.
    ///
    /// - Parameters:
    ///   - id: Optional. Unique identifier of the tool call. (Gemini Developer API only). For more details, see ``id``.
    ///   - toolType: Required. The type of tool that was called. (Gemini Developer API only). For more details, see ``toolType``.
    ///   - args: Optional. The tool call arguments. (Gemini Developer API only). For more details, see ``args``.
    package init(
      id: String? = nil,
      toolType: ToolType,
      args: [String: JSONValue]? = nil
    ) {
      self.id = id
      self.toolType = toolType
      self.args = args
    }
    enum CodingKeys: String, CodingKey {
      case id = "id"
      case toolType = "toolType"
      case args = "args"
    }
  }
}