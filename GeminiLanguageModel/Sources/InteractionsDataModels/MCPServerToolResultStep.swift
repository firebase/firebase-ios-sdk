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

/// MCPServer tool result step.
package struct MCPServerToolResultStep: Codable, Sendable, Equatable, Hashable {

  /// Required. ID to match the ID from the function call block.
  package let callId: String?

  /// Name of the tool which is called for this specific tool call.
  package let name: String?

  /// Required. The output from the MCP server call. Can be simple text or rich content.
  package let result: JSONValue?

  /// The name of the used MCP server.
  package let serverName: String?

  package let type: String?

  /// Creates a new `MCPServerToolResultStep`.
  ///
  /// - Parameters:
  ///   - callId: Required. ID to match the ID from the function call block.
  ///   - name: Name of the tool which is called for this specific tool call.
  ///   - result: Required. The output from the MCP server call. Can be simple text or rich content.
  ///   - serverName: The name of the used MCP server.
  package init(
    callId: String?,
    name: String? = nil,
    result: JSONValue?,
    serverName: String? = nil
  ) {
    self.callId = callId
    self.name = name
    self.result = result
    self.serverName = serverName
    self.type = "mcp_server_tool_result"
  }
  enum CodingKeys: String, CodingKey {
    case callId = "call_id"
    case name = "name"
    case result = "result"
    case serverName = "server_name"
    case type = "type"
  }
}
