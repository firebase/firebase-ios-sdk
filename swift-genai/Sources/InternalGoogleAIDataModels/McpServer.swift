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
  /// A MCPServer is a server that can be called by the model to perform actions. It is a server that implements the MCP protocol. Next ID: 6
  public struct McpServer: Codable, Sendable, Equatable, Hashable {
    /// The name of the MCPServer.
    public var name: String?
    
    /// A transport that can stream HTTP requests and responses.
    public var streamableHttpTransport: StreamableHttpTransport?
    
    /// Creates a new `McpServer`.
    public init(
      name: String? = nil,
      streamableHttpTransport: StreamableHttpTransport? = nil
    ) {
      self.name = name
      self.streamableHttpTransport = streamableHttpTransport
    }
    enum CodingKeys: String, CodingKey {
      case name = "name"
      case streamableHttpTransport = "streamableHttpTransport"
    }
  }
}