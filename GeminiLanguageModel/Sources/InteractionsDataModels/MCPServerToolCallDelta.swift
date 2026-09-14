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

/// An internal data model for `MCPServerToolCallDelta`.
package struct MCPServerToolCallDelta: Codable, Sendable, Equatable, Hashable {

  package let arguments: [String: JSONValue]?

  package let name: String?

  package let serverName: String?

  package let type: String?

  /// Creates a new `MCPServerToolCallDelta`.
  ///
  /// - Parameters:
  ///   - arguments: For more details, see ``arguments``.
  ///   - name: For more details, see ``name``.
  ///   - serverName: For more details, see ``serverName``.
  package init(
    arguments: [String: JSONValue]?,
    name: String?,
    serverName: String?
  ) {
    self.arguments = arguments
    self.name = name
    self.serverName = serverName
    self.type = "mcp_server_tool_call"
  }
  enum CodingKeys: String, CodingKey {
    case arguments = "arguments"
    case name = "name"
    case serverName = "server_name"
    case type = "type"
  }
}
