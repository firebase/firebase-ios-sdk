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

/// A tool that can be used by the model to interact with the computer.
package struct ComputerUse: Codable, Sendable, Equatable, Hashable {

  /// Optional. Disabled safety policies for computer use.
  package let disabledSafetyPolicies: [String]?

  /// Whether enable the prompt injection detection check on computer-use
  /// request.
  package let enablePromptInjectionDetection: Bool?

  /// The environment being operated.
  package let environment: Environment?

  /// The list of predefined functions that are excluded from the model call.
  package let excludedPredefinedFunctions: [String]?

  package let type: String?

  /// Creates a new `ComputerUse`.
  ///
  /// - Parameters:
  ///   - disabledSafetyPolicies: Optional. Disabled safety policies for computer use.
  ///   - enablePromptInjectionDetection: Whether enable the prompt injection detection check on computer-use
  ///   - environment: The environment being operated.
  ///   - excludedPredefinedFunctions: The list of predefined functions that are excluded from the model call.
  package init(
    disabledSafetyPolicies: [String]? = nil,
    enablePromptInjectionDetection: Bool? = nil,
    environment: Environment? = nil,
    excludedPredefinedFunctions: [String]? = nil
  ) {
    self.disabledSafetyPolicies = disabledSafetyPolicies
    self.enablePromptInjectionDetection = enablePromptInjectionDetection
    self.environment = environment
    self.excludedPredefinedFunctions = excludedPredefinedFunctions
    self.type = "computer_use"
  }
  enum CodingKeys: String, CodingKey {
    case disabledSafetyPolicies = "disabled_safety_policies"
    case enablePromptInjectionDetection = "enable_prompt_injection_detection"
    case environment = "environment"
    case excludedPredefinedFunctions = "excluded_predefined_functions"
    case type = "type"
  }
}
