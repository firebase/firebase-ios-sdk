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

/// An internal data model for `MCPServerToolResultDelta`.
package struct MCPServerToolResultDelta: Codable, Sendable, Equatable, Hashable {

  package let name: String?

  package let result: JSONValue?

  package let serverName: String?

  package let type: String?

  /// Creates a new `MCPServerToolResultDelta`.
  ///
  /// - Parameters:
  ///   - name: For more details, see ``name``.
  ///   - result: For more details, see ``result``.
  ///   - serverName: For more details, see ``serverName``.
  package init(
    name: String? = nil,
    result: JSONValue?,
    serverName: String? = nil
  ) {
    self.name = name
    self.result = result
    self.serverName = serverName
    self.type = "mcp_server_tool_result"
  }
  enum CodingKeys: String, CodingKey {
    case name = "name"
    case result = "result"
    case serverName = "server_name"
    case type = "type"
  }
}
