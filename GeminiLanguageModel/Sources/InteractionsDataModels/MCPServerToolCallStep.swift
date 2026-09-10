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

/// MCPServer tool call step.
package struct MCPServerToolCallStep: Codable, Sendable, Equatable, Hashable {

  /// Required. The JSON object of arguments for the function.
  package let arguments: [String: JSONValue]?

  /// Required. A unique ID for this specific tool call.
  package let id: String?

  /// Required. The name of the tool which was called.
  package let name: String?

  /// Required. The name of the used MCP server.
  package let serverName: String?

  package let type: String?

  /// Creates a new `MCPServerToolCallStep`.
  ///
  /// - Parameters:
  ///   - arguments: Required. The JSON object of arguments for the function.
  ///   - id: Required. A unique ID for this specific tool call.
  ///   - name: Required. The name of the tool which was called.
  ///   - serverName: Required. The name of the used MCP server.
  package init(
    arguments: [String: JSONValue]?,
    id: String?,
    name: String?,
    serverName: String?
  ) {
    self.arguments = arguments
    self.id = id
    self.name = name
    self.serverName = serverName
    self.type = "mcp_server_tool_call"
  }
  enum CodingKeys: String, CodingKey {
    case arguments = "arguments"
    case id = "id"
    case name = "name"
    case serverName = "server_name"
    case type = "type"
  }
}
