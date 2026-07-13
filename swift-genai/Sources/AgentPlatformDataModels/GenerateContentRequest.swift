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
  /// Request message for [PredictionService.GenerateContent].
  package struct GenerateContentRequest: Codable, Sendable, Equatable, Hashable {
    /// Optional. The name of the cached content used as context to serve the prediction. Note: only used in explicit caching, where users can have control over caching (e.g. what content to cache) and enjoy guaranteed cost savings. Format: `projects/{project}/locations/{location}/cachedContents/{cachedContent}`
    package var cachedContent: String?
    
    /// Required. The content of the current conversation with the model. For single-turn queries, this is a single instance. For multi-turn queries, this is a repeated field that contains conversation history + latest request.
    package var contents: [Content]?
    
    /// Optional. Generation config.
    package var generationConfig: GenerationConfig?
    
    /// Optional. The labels with user-defined metadata for the request. It is used for billing and reporting only. Label keys and values can be no longer than 63 characters (Unicode codepoints) and can only contain lowercase letters, numeric characters, underscores, and dashes. International characters are allowed. Label values are optional. Label keys must start with a letter.
    package var labels: [String: String]?
    
    /// Optional. Settings for prompt and response sanitization using the Model Armor service. If supplied, safety_settings must not be supplied.
    package var modelArmorConfig: ModelArmorConfig?
    
    /// Optional. Per request settings for blocking unsafe content. Enforced on GenerateContentResponse.candidates.
    package var safetySettings: [SafetySetting]?
    
    /// Optional. The user provided system instructions for the model. Note: only text should be used in parts and content in each part will be in a separate paragraph.
    package var systemInstruction: Content?
    
    /// Optional. Tool config. This config is shared for all tools provided in the request.
    package var toolConfig: ToolConfig?
    
    /// Optional. A list of `Tools` the model may use to generate the next response. A `Tool` is a piece of code that enables the system to interact with external systems to perform an action, or set of actions, outside of knowledge and scope of the model.
    package var tools: [Tool]?
    
    /// Creates a new `GenerateContentRequest`.
    package init(
      cachedContent: String? = nil,
      contents: [Content]? = nil,
      generationConfig: GenerationConfig? = nil,
      labels: [String: String]? = nil,
      modelArmorConfig: ModelArmorConfig? = nil,
      safetySettings: [SafetySetting]? = nil,
      systemInstruction: Content? = nil,
      toolConfig: ToolConfig? = nil,
      tools: [Tool]? = nil
    ) {
      self.cachedContent = cachedContent
      self.contents = contents
      self.generationConfig = generationConfig
      self.labels = labels
      self.modelArmorConfig = modelArmorConfig
      self.safetySettings = safetySettings
      self.systemInstruction = systemInstruction
      self.toolConfig = toolConfig
      self.tools = tools
    }
    enum CodingKeys: String, CodingKey {
      case cachedContent = "cachedContent"
      case contents = "contents"
      case generationConfig = "generationConfig"
      case labels = "labels"
      case modelArmorConfig = "modelArmorConfig"
      case safetySettings = "safetySettings"
      case systemInstruction = "systemInstruction"
      case toolConfig = "toolConfig"
      case tools = "tools"
    }
  }
}