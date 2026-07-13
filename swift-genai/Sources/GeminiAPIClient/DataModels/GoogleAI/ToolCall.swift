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

extension GoogleAI {
  /// A predicted server-side `ToolCall` returned from the model. This message contains information about a tool that the model wants to invoke. The client is NOT expected to execute this `ToolCall`. Instead, the client should pass this `ToolCall` back to the API in a subsequent turn within a `Content` message, along with the corresponding `ToolResponse`.
  package struct ToolCall: Codable, Sendable, Equatable, Hashable {
    /// Optional. The tool call arguments. Example: {"arg1" : "value1", "arg2" : "value2" , ...}
    package var args: [String: JSONValue]?
    
    /// Optional. Unique identifier of the tool call. The server returns the tool response with the matching `id`.
    package var id: String?
    
    /// Required. The type of tool that was called.
    package var toolType: ToolType?
    
    /// Creates a new `ToolCall`.
    package init(
      args: [String: JSONValue]? = nil,
      id: String? = nil,
      toolType: ToolType? = nil
    ) {
      self.args = args
      self.id = id
      self.toolType = toolType
    }
    enum CodingKeys: String, CodingKey {
      case args = "args"
      case id = "id"
      case toolType = "toolType"
    }
  }
}