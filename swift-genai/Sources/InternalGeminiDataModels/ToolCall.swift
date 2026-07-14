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
  /// A predicted server-side `ToolCall` returned from the model. This message contains information about a tool that the model wants to invoke. The client is NOT expected to execute this `ToolCall`. Instead, the client should pass this `ToolCall` back to the API in a subsequent turn within a `Content` message, along with the corresponding `ToolResponse`.
  /// 
  /// > Important: This type is only available in the Gemini Developer API.
  package struct ToolCall: Codable, Sendable, Equatable, Hashable {
    /// Required. The type of tool that was called.
    /// 
    /// > Important: `toolType` is only available in the Gemini Developer API.
    package let toolType: ToolType?
    
    /// Optional. Unique identifier of the tool call. The server returns the tool response with the matching `id`.
    /// 
    /// > Important: `id` is only available in the Gemini Developer API.
    package let id: String?
    
    /// Optional. The tool call arguments. Example: {"arg1" : "value1", "arg2" : "value2" , ...}
    /// 
    /// > Important: `args` is only available in the Gemini Developer API.
    package let args: [String: JSONValue]?
    
    /// Creates a new `ToolCall`.
    package init(
      toolType: ToolType? = nil,
      id: String? = nil,
      args: [String: JSONValue]? = nil
    ) {
      self.toolType = toolType
      self.id = id
      self.args = args
    }
    enum CodingKeys: String, CodingKey {
      case toolType = "toolType"
      case id = "id"
      case args = "args"
    }
  }
}