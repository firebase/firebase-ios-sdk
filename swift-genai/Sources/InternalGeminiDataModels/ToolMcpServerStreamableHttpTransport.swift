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
  /// An internal data model for `ToolMcpServerStreamableHttpTransport`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaToolMcpServerStreamableHttpTransport`
  /// 
  /// A transport that can stream HTTP requests and responses.
  /// Next ID: 6
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct ToolMcpServerStreamableHttpTransport: Codable, Sendable, Equatable, Hashable {
    /// The full URL for the MCPServer endpoint.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The full URL for the MCPServer endpoint.
    /// Example: "https://api.example.com/mcp"
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let url: String?
    
    /// Optional: Fields for authentication headers, timeouts, etc., if needed.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional: Fields for authentication headers, timeouts, etc., if needed.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let headers: [String: String]?
    
    /// HTTP timeout for regular operations.
    /// 
    /// ### Gemini Developer API
    /// 
    /// HTTP timeout for regular operations.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let timeout: String?
    
    /// Timeout for SSE read operations.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Timeout for SSE read operations.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let sseReadTimeout: String?
    
    /// Whether to close the client session when the transport closes.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Whether to close the client session when the transport closes.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let terminateOnClose: Bool?
    

    /// Creates a new `ToolMcpServerStreamableHttpTransport`.
    ///
    /// - Parameters:
    ///   - url: The full URL for the MCPServer endpoint. (Gemini Developer API only). For more details, see ``url``.
    ///   - headers: Optional: Fields for authentication headers, timeouts, etc., if needed. (Gemini Developer API only). For more details, see ``headers``.
    ///   - timeout: HTTP timeout for regular operations. (Gemini Developer API only). For more details, see ``timeout``.
    ///   - sseReadTimeout: Timeout for SSE read operations. (Gemini Developer API only). For more details, see ``sseReadTimeout``.
    ///   - terminateOnClose: Whether to close the client session when the transport closes. (Gemini Developer API only). For more details, see ``terminateOnClose``.
    package init(
      url: String? = nil,
      headers: [String: String]? = nil,
      timeout: String? = nil,
      sseReadTimeout: String? = nil,
      terminateOnClose: Bool? = nil
    ) {
      self.url = url
      self.headers = headers
      self.timeout = timeout
      self.sseReadTimeout = sseReadTimeout
      self.terminateOnClose = terminateOnClose
    }
    enum CodingKeys: String, CodingKey {
      case url = "url"
      case headers = "headers"
      case timeout = "timeout"
      case sseReadTimeout = "sseReadTimeout"
      case terminateOnClose = "terminateOnClose"
    }
  }
}