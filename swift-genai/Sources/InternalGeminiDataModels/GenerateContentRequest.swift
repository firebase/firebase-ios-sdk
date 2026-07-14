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
  /// Request to generate a completion from the model.
  /// 
  /// Variant:
  /// Request message for [PredictionService.GenerateContent].
  package struct GenerateContentRequest: Codable, Sendable, Equatable, Hashable {
    /// Optional. Tool configuration for any `Tool` specified in the request. Refer to the [Function calling guide](https://ai.google.dev/gemini-api/docs/function-calling#function_calling_mode) for a usage example.
    /// 
    /// Variant:
    /// Optional. Tool config. This config is shared for all tools provided in the request.
    package let toolConfig: ToolConfig?
    
    /// Optional. A list of unique `SafetySetting` instances for blocking unsafe content. This will be enforced on the `GenerateContentRequest.contents` and `GenerateContentResponse.candidates`. There should not be more than one setting for each `SafetyCategory` type. The API will block any contents and responses that fail to meet the thresholds set by these settings. This list overrides the default settings for each `SafetyCategory` specified in the safety_settings. If there is no `SafetySetting` for a given `SafetyCategory` provided in the list, the API will use the default safety setting for that category. Harm categories HARM_CATEGORY_HATE_SPEECH, HARM_CATEGORY_SEXUALLY_EXPLICIT, HARM_CATEGORY_DANGEROUS_CONTENT, HARM_CATEGORY_HARASSMENT, HARM_CATEGORY_CIVIC_INTEGRITY are supported. Refer to the [guide](https://ai.google.dev/gemini-api/docs/safety-settings) for detailed information on available safety settings. Also refer to the [Safety guidance](https://ai.google.dev/gemini-api/docs/safety-guidance) to learn how to incorporate safety considerations in your AI applications.
    /// 
    /// Variant:
    /// Optional. Per request settings for blocking unsafe content. Enforced on GenerateContentResponse.candidates.
    package let safetySettings: [SafetySetting]?
    
    /// Optional. The labels with user-defined metadata for the request. It is used for billing and reporting only. Label keys and values can be no longer than 63 characters (Unicode codepoints) and can only contain lowercase letters, numeric characters, underscores, and dashes. International characters are allowed. Label values are optional. Label keys must start with a letter.
    /// 
    /// > Important: `labels` is only available in the Gemini Enterprise Agent Platform.
    package let labels: [String: String]?
    
    /// Required. The content of the current conversation with the model. For single-turn queries, this is a single instance. For multi-turn queries like [chat](https://ai.google.dev/gemini-api/docs/text-generation#chat), this is a repeated field that contains the conversation history and the latest request.
    /// 
    /// Variant:
    /// Required. The content of the current conversation with the model. For single-turn queries, this is a single instance. For multi-turn queries, this is a repeated field that contains conversation history + latest request.
    package let contents: [Content]?
    
    /// Optional. A list of `Tools` the `Model` may use to generate the next response. A `Tool` is a piece of code that enables the system to interact with external systems to perform an action, or set of actions, outside of knowledge and scope of the `Model`. Supported `Tool`s are `Function` and `code_execution`. Refer to the [Function calling](https://ai.google.dev/gemini-api/docs/function-calling) and the [Code execution](https://ai.google.dev/gemini-api/docs/code-execution) guides to learn more.
    /// 
    /// Variant:
    /// Optional. A list of `Tools` the model may use to generate the next response. A `Tool` is a piece of code that enables the system to interact with external systems to perform an action, or set of actions, outside of knowledge and scope of the model.
    package let tools: [Tool]?
    
    /// Optional. The name of the content [cached](https://ai.google.dev/gemini-api/docs/caching) to use as context to serve the prediction. Format: `cachedContents/{cachedContent}`
    /// 
    /// Variant:
    /// Optional. The name of the cached content used as context to serve the prediction. Note: only used in explicit caching, where users can have control over caching (e.g. what content to cache) and enjoy guaranteed cost savings. Format: `projects/{project}/locations/{location}/cachedContents/{cachedContent}`
    package let cachedContent: String?
    
    /// Required. The name of the `Model` to use for generating the completion. Format: `models/{model}`.
    /// 
    /// > Important: `model` is only available in the Gemini Developer API.
    package let model: String?
    
    /// Optional. Configuration options for model generation and outputs.
    /// 
    /// Variant:
    /// Optional. Generation config.
    package let generationConfig: GenerationConfig?
    
    /// Optional. Settings for prompt and response sanitization using the Model Armor service. If supplied, safety_settings must not be supplied.
    /// 
    /// > Important: `modelArmorConfig` is only available in the Gemini Enterprise Agent Platform.
    package let modelArmorConfig: ModelArmorConfig?
    
    /// Optional. Developer set [system instruction(s)](https://ai.google.dev/gemini-api/docs/system-instructions). Currently, text only.
    /// 
    /// Variant:
    /// Optional. The user provided system instructions for the model. Note: only text should be used in parts and content in each part will be in a separate paragraph.
    package let systemInstruction: Content?
    
    /// Optional. The service tier of the request.
    /// 
    /// > Important: `serviceTier` is only available in the Gemini Developer API.
    package let serviceTier: ServiceTier?
    
    /// Optional. Configures the logging behavior for a given request. If set, it takes precedence over the project-level logging config.
    /// 
    /// > Important: `store` is only available in the Gemini Developer API.
    package let store: Bool?
    
    /// Creates a new `GenerateContentRequest`.
    package init(
      toolConfig: ToolConfig? = nil,
      safetySettings: [SafetySetting]? = nil,
      labels: [String: String]? = nil,
      contents: [Content]? = nil,
      tools: [Tool]? = nil,
      cachedContent: String? = nil,
      model: String? = nil,
      generationConfig: GenerationConfig? = nil,
      modelArmorConfig: ModelArmorConfig? = nil,
      systemInstruction: Content? = nil,
      serviceTier: ServiceTier? = nil,
      store: Bool? = nil
    ) {
      self.toolConfig = toolConfig
      self.safetySettings = safetySettings
      self.labels = labels
      self.contents = contents
      self.tools = tools
      self.cachedContent = cachedContent
      self.model = model
      self.generationConfig = generationConfig
      self.modelArmorConfig = modelArmorConfig
      self.systemInstruction = systemInstruction
      self.serviceTier = serviceTier
      self.store = store
    }
    enum CodingKeys: String, CodingKey {
      case toolConfig = "toolConfig"
      case safetySettings = "safetySettings"
      case labels = "labels"
      case contents = "contents"
      case tools = "tools"
      case cachedContent = "cachedContent"
      case model = "model"
      case generationConfig = "generationConfig"
      case modelArmorConfig = "modelArmorConfig"
      case systemInstruction = "systemInstruction"
      case serviceTier = "serviceTier"
      case store = "store"
    }
  }
}