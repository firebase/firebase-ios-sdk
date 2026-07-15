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


extension GeminiDataModels {
  /// An internal data model for `ToolMcpServer`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaToolMcpServer`
  /// 
  /// A MCPServer is a server that can be called by the model to perform actions.
  /// It is a server that implements the MCP protocol.
  /// Next ID: 6
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct ToolMcpServer: Codable, Sendable, Equatable, Hashable {
    /// A transport that can stream HTTP requests and responses.
    /// 
    /// ### Gemini Developer API
    /// 
    /// A transport that can stream HTTP requests and responses.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let streamableHttpTransport: ToolMcpServerStreamableHttpTransport?
    
    /// The name of the MCPServer.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The name of the MCPServer.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let name: String?
    

    /// Creates a new `ToolMcpServer`.
    ///
    /// - Parameters:
    ///   - streamableHttpTransport: A transport that can stream HTTP requests and responses. (Gemini Developer API only). For more details, see ``streamableHttpTransport``.
    ///   - name: The name of the MCPServer. (Gemini Developer API only). For more details, see ``name``.
    package init(
      streamableHttpTransport: ToolMcpServerStreamableHttpTransport? = nil,
      name: String? = nil
    ) {
      self.streamableHttpTransport = streamableHttpTransport
      self.name = name
    }
    enum CodingKeys: String, CodingKey {
      case streamableHttpTransport = "streamableHttpTransport"
      case name = "name"
    }
  }
}