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


extension AgentPlatform {
  /// Tool config. This config is shared for all tools provided in the request.
  package struct ToolConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Function calling config.
    package var functionCallingConfig: FunctionCallingConfig?
    
    /// Optional. Retrieval config.
    package var retrievalConfig: RetrievalConfig?
    
    /// Creates a new `ToolConfig`.
    package init(
      functionCallingConfig: FunctionCallingConfig? = nil,
      retrievalConfig: RetrievalConfig? = nil
    ) {
      self.functionCallingConfig = functionCallingConfig
      self.retrievalConfig = retrievalConfig
    }
    enum CodingKeys: String, CodingKey {
      case functionCallingConfig = "functionCallingConfig"
      case retrievalConfig = "retrievalConfig"
    }
  }
}