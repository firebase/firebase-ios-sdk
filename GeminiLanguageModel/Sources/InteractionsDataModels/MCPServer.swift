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

/// A MCPServer is a server that can be called by the model to perform actions.
package struct MCPServer: Codable, Sendable, Equatable, Hashable {

  /// The allowed tools.
  package let allowedTools: [AllowedTools]?

  /// Optional: Fields for authentication headers, timeouts, etc., if needed.
  package let headers: [String: String]?

  /// The name of the MCPServer.
  package let name: String?

  package let type: String?

  /// The full URL for the MCPServer endpoint.
  /// Example: "https://api.example.com/mcp"
  package let url: String?

  /// Creates a new `MCPServer`.
  ///
  /// - Parameters:
  ///   - allowedTools: The allowed tools.
  ///   - headers: Optional: Fields for authentication headers, timeouts, etc., if needed.
  ///   - name: The name of the MCPServer.
  ///   - url: The full URL for the MCPServer endpoint.
  package init(
    allowedTools: [AllowedTools]? = nil,
    headers: [String: String]? = nil,
    name: String? = nil,
    url: String? = nil
  ) {
    self.allowedTools = allowedTools
    self.headers = headers
    self.name = name
    self.type = "mcp_server"
    self.url = url
  }
  enum CodingKeys: String, CodingKey {
    case allowedTools = "allowed_tools"
    case headers = "headers"
    case name = "name"
    case type = "type"
    case url = "url"
  }
}
