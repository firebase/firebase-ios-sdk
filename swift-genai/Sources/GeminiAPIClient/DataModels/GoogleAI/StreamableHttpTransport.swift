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
  /// A transport that can stream HTTP requests and responses. Next ID: 6
  package struct StreamableHttpTransport: Codable, Sendable, Equatable, Hashable {
    /// Optional: Fields for authentication headers, timeouts, etc., if needed.
    package var headers: [String: String]?
    
    /// Timeout for SSE read operations.
    package var sseReadTimeout: Duration?
    
    /// Whether to close the client session when the transport closes.
    package var terminateOnClose: Bool?
    
    /// HTTP timeout for regular operations.
    package var timeout: Duration?
    
    /// The full URL for the MCPServer endpoint. Example: "https://api.example.com/mcp"
    package var url: String?
    
    /// Creates a new `StreamableHttpTransport`.
    package init(
      headers: [String: String]? = nil,
      sseReadTimeout: Duration? = nil,
      terminateOnClose: Bool? = nil,
      timeout: Duration? = nil,
      url: String? = nil
    ) {
      self.headers = headers
      self.sseReadTimeout = sseReadTimeout
      self.terminateOnClose = terminateOnClose
      self.timeout = timeout
      self.url = url
    }
    enum CodingKeys: String, CodingKey {
      case headers = "headers"
      case sseReadTimeout = "sseReadTimeout"
      case terminateOnClose = "terminateOnClose"
      case timeout = "timeout"
      case url = "url"
    }
  }
}