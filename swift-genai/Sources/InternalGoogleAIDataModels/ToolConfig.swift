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
  /// The Tool configuration containing parameters for specifying `Tool` use in the request.
  public struct ToolConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Function calling config.
    public var functionCallingConfig: FunctionCallingConfig?
    
    /// Optional. If true, the API response will include the server-side tool calls and responses within the `Content` message. This allows clients to observe the server's tool interactions.
    public var includeServerSideToolInvocations: Bool?
    
    /// Optional. Retrieval config.
    public var retrievalConfig: RetrievalConfig?
    
    /// Creates a new `ToolConfig`.
    public init(
      functionCallingConfig: FunctionCallingConfig? = nil,
      includeServerSideToolInvocations: Bool? = nil,
      retrievalConfig: RetrievalConfig? = nil
    ) {
      self.functionCallingConfig = functionCallingConfig
      self.includeServerSideToolInvocations = includeServerSideToolInvocations
      self.retrievalConfig = retrievalConfig
    }
    enum CodingKeys: String, CodingKey {
      case functionCallingConfig = "functionCallingConfig"
      case includeServerSideToolInvocations = "includeServerSideToolInvocations"
      case retrievalConfig = "retrievalConfig"
    }
  }
}