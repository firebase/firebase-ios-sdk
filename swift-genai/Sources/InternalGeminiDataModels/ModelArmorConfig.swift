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
  /// Configuration for Model Armor. Model Armor is a Google Cloud service that provides safety and security filtering for prompts and responses. It helps protect your AI applications from risks such as harmful content, sensitive data leakage, and prompt injection attacks.
  /// 
  /// > Important: This type is only available in the Gemini Enterprise Agent Platform.
  package struct ModelArmorConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The resource name of the Model Armor template to use for prompt screening. A Model Armor template is a set of customized filters and thresholds that define how Model Armor screens content. If specified, Model Armor will use this template to check the user's prompt for safety and security risks before it is sent to the model. The name must be in the format `projects/{project}/locations/{location}/templates/{template}`.
    /// 
    /// > Important: `promptTemplateName` is only available in the Gemini Enterprise Agent Platform.
    package let promptTemplateName: String?
    
    /// Optional. The resource name of the Model Armor template to use for response screening. A Model Armor template is a set of customized filters and thresholds that define how Model Armor screens content. If specified, Model Armor will use this template to check the model's response for safety and security risks before it is returned to the user. The name must be in the format `projects/{project}/locations/{location}/templates/{template}`.
    /// 
    /// > Important: `responseTemplateName` is only available in the Gemini Enterprise Agent Platform.
    package let responseTemplateName: String?
    
    /// Creates a new `ModelArmorConfig`.
    package init(
      promptTemplateName: String? = nil,
      responseTemplateName: String? = nil
    ) {
      self.promptTemplateName = promptTemplateName
      self.responseTemplateName = responseTemplateName
    }
    enum CodingKeys: String, CodingKey {
      case promptTemplateName = "promptTemplateName"
      case responseTemplateName = "responseTemplateName"
    }
  }
}