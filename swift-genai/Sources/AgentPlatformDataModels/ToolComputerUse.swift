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
  /// Tool to support computer use.
  package struct ToolComputerUse: Codable, Sendable, Equatable, Hashable {
    /// Optional. Enables the prompt injection detection check on computer-use request.
    package var enablePromptInjectionDetection: Bool?
    
    /// Required. The environment being operated.
    package var environment: Environment?
    
    /// Optional. By default, [predefined functions](https://cloud.google.com/vertex-ai/generative-ai/docs/computer-use#supported-actions) are included in the final model call. Some of them can be explicitly excluded from being automatically included. This can serve two purposes: 1. Using a more restricted / different action space. 2. Improving the definitions / instructions of predefined functions.
    package var excludedPredefinedFunctions: [String]?
    
    /// Creates a new `ToolComputerUse`.
    package init(
      enablePromptInjectionDetection: Bool? = nil,
      environment: Environment? = nil,
      excludedPredefinedFunctions: [String]? = nil
    ) {
      self.enablePromptInjectionDetection = enablePromptInjectionDetection
      self.environment = environment
      self.excludedPredefinedFunctions = excludedPredefinedFunctions
    }
    enum CodingKeys: String, CodingKey {
      case enablePromptInjectionDetection = "enablePromptInjectionDetection"
      case environment = "environment"
      case excludedPredefinedFunctions = "excludedPredefinedFunctions"
    }
  }
}