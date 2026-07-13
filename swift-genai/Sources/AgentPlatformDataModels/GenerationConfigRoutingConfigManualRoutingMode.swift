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
  /// The configuration for manual routing. When manual routing is specified, the model will be selected based on the model name provided.
  package struct GenerationConfigRoutingConfigManualRoutingMode: Codable, Sendable, Equatable, Hashable {
    /// The name of the model to use. Only public LLM models are accepted.
    package var modelName: String?
    
    /// Creates a new `GenerationConfigRoutingConfigManualRoutingMode`.
    package init(
      modelName: String? = nil
    ) {
      self.modelName = modelName
    }
    enum CodingKeys: String, CodingKey {
      case modelName = "modelName"
    }
  }
}