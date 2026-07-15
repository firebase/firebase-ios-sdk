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
  /// An internal data model for `ToolConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `ToolConfig`
  /// 
  /// Tool config. This config is shared for all tools provided in the request.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ToolConfig`
  /// 
  /// Tool config. This config is shared for all tools provided in the request.
  package struct ToolConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Retrieval config.
    package let retrievalConfig: RetrievalConfig?
    
    /// Optional. Function calling config.
    package let functionCallingConfig: FunctionCallingConfig?
    
    /// Optional. If true, the API response will include the server-side tool calls and
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. If true, the API response will include the server-side tool calls and
    /// responses within the `Content` message. This allows clients to
    /// observe the server's tool interactions.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let includeServerSideToolInvocations: Bool?
    

    /// Creates a new `ToolConfig`.
    ///
    /// - Parameters:
    ///   - retrievalConfig: Optional. Retrieval config.
    ///   - functionCallingConfig: Optional. Function calling config.
    ///   - includeServerSideToolInvocations: Optional. If true, the API response will include the server-side tool calls and (Gemini Developer API only). For more details, see ``includeServerSideToolInvocations``.
    package init(
      retrievalConfig: RetrievalConfig? = nil,
      functionCallingConfig: FunctionCallingConfig? = nil,
      includeServerSideToolInvocations: Bool? = nil
    ) {
      self.retrievalConfig = retrievalConfig
      self.functionCallingConfig = functionCallingConfig
      self.includeServerSideToolInvocations = includeServerSideToolInvocations
    }
    enum CodingKeys: String, CodingKey {
      case retrievalConfig = "retrievalConfig"
      case functionCallingConfig = "functionCallingConfig"
      case includeServerSideToolInvocations = "includeServerSideToolInvocations"
    }
  }
}