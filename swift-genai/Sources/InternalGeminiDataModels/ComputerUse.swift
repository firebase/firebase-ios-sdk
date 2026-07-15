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
  /// An internal data model for `ComputerUse`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaToolComputerUse`
  /// 
  /// Computer Use tool type.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ToolComputerUse`
  /// 
  /// Tool to support computer use.
  package struct ComputerUse: Codable, Sendable, Equatable, Hashable {
    /// Required. The environment being operated.
    package let environment: Environment
    
    /// Optional. By default, predefined functions are included in the final model
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. By default, predefined functions are included in the final model
    /// call.
    /// Some of them can be explicitly excluded from being automatically
    /// included. This can serve two purposes:
    /// 1. Using a more restricted / different action space.
    /// 2. Improving the definitions / instructions of predefined functions.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. By default, [predefined
    /// functions](https://cloud.google.com/vertex-ai/generative-ai/docs/computer-use#supported-actions)
    /// are included in the final model call. Some of them can be explicitly
    /// excluded from being automatically included. This can serve two purposes:
    /// 1. Using a more restricted / different action space.
    /// 2. Improving the definitions / instructions of predefined functions.
    package let excludedPredefinedFunctions: [String]?
    
    /// Optional. Whether enable the prompt injection detection check on computer-use
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Whether enable the prompt injection detection check on computer-use
    /// request.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Enables the prompt injection detection check on computer-use request.
    package let enablePromptInjectionDetection: Bool?
    
    /// Optional. Disabled safety policies for computer use.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Disabled safety policies for computer use.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let disabledSafetyPolicies: [String]?
    

    /// Creates a new `ComputerUse`.
    ///
    /// - Parameters:
    ///   - environment: Required. The environment being operated.
    ///   - excludedPredefinedFunctions: Optional. By default, predefined functions are included in the final model (behavior varies by backend). For more details, see ``excludedPredefinedFunctions``.
    ///   - enablePromptInjectionDetection: Optional. Whether enable the prompt injection detection check on computer-use (behavior varies by backend). For more details, see ``enablePromptInjectionDetection``.
    ///   - disabledSafetyPolicies: Optional. Disabled safety policies for computer use. (Gemini Developer API only). For more details, see ``disabledSafetyPolicies``.
    package init(
      environment: Environment,
      excludedPredefinedFunctions: [String]? = nil,
      enablePromptInjectionDetection: Bool? = nil,
      disabledSafetyPolicies: [String]? = nil
    ) {
      self.environment = environment
      self.excludedPredefinedFunctions = excludedPredefinedFunctions
      self.enablePromptInjectionDetection = enablePromptInjectionDetection
      self.disabledSafetyPolicies = disabledSafetyPolicies
    }
    enum CodingKeys: String, CodingKey {
      case environment = "environment"
      case excludedPredefinedFunctions = "excludedPredefinedFunctions"
      case enablePromptInjectionDetection = "enablePromptInjectionDetection"
      case disabledSafetyPolicies = "disabledSafetyPolicies"
    }
  }
}