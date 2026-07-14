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
  /// Request for performing a GenerateContent operation.
  package struct TemplateGenerateContentRequest: Codable, Sendable, Equatable, Hashable {
    /// Optional. Tool configuration for any tool specified in the request.
    package let toolConfig: ToolConfig?
    
    /// Optional. Conversation history for multi-turn prompts and function calling.
    package let history: [HistoryContent]?
    
    /// Optional. Client provided data that can be used when rendering the template. When calling via JSON/http surfaces this should be wire compatible with an arbitrary JSON object.
    package let inputs: [String: JSONValue]?
    
    /// Optional. A list of tools that the model may use to generate the response.
    package let tools: [Tool]?
    
    /// Creates a new `TemplateGenerateContentRequest`.
    package init(
      toolConfig: ToolConfig? = nil,
      history: [HistoryContent]? = nil,
      inputs: [String: JSONValue]? = nil,
      tools: [Tool]? = nil
    ) {
      self.toolConfig = toolConfig
      self.history = history
      self.inputs = inputs
      self.tools = tools
    }
    enum CodingKeys: String, CodingKey {
      case toolConfig = "toolConfig"
      case history = "history"
      case inputs = "inputs"
      case tools = "tools"
    }
  }
}