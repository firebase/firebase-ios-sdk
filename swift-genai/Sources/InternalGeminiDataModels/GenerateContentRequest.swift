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
  /// An internal data model for `GenerateContentRequest`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGenerateContentRequest`
  /// 
  /// Request to generate a completion from the model.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GenerateContentRequest`
  /// 
  /// Request message for [PredictionService.GenerateContent].
  package struct GenerateContentRequest: Codable, Sendable, Equatable, Hashable {
    /// Required. The name of the `Model` to use for generating the completion.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The name of the `Model` to use for generating the completion.
    /// 
    /// Format: `models/{model}`.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let model: String?
    
    /// Optional. Developer set [system
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Developer set [system
    /// instruction(s)](https://ai.google.dev/gemini-api/docs/system-instructions).
    /// Currently, text only.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The user provided system instructions for the model.
    /// Note: only text should be used in parts and content in each part will be in
    /// a separate paragraph.
    package let systemInstruction: Content?
    
    /// Required. The content of the current conversation with the model.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The content of the current conversation with the model.
    /// 
    /// For single-turn queries, this is a single instance. For multi-turn queries
    /// like [chat](https://ai.google.dev/gemini-api/docs/text-generation#chat),
    /// this is a repeated field that contains the conversation history and the
    /// latest request.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The content of the current conversation with the model.
    /// 
    /// For single-turn queries, this is a single instance. For multi-turn queries,
    /// this is a repeated field that contains conversation history + latest
    /// request.
    package let contents: [Content]
    
    /// Optional. A list of `Tools` the `Model` may use to generate the next response.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. A list of `Tools` the `Model` may use to generate the next response.
    /// 
    /// A `Tool` is a piece of code that enables the system to interact with
    /// external systems to perform an action, or set of actions, outside of
    /// knowledge and scope of the `Model`. Supported `Tool`s are `Function` and
    /// `code_execution`. Refer to the [Function
    /// calling](https://ai.google.dev/gemini-api/docs/function-calling) and the
    /// [Code execution](https://ai.google.dev/gemini-api/docs/code-execution)
    /// guides to learn more.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. A list of `Tools` the model may use to generate the next response.
    /// 
    /// A `Tool` is a piece of code that enables the system to interact with
    /// external systems to perform an action, or set of actions, outside of
    /// knowledge and scope of the model.
    package let tools: [Tool]?
    
    /// Optional. Tool configuration for any `Tool` specified in the request. Refer to the
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Tool configuration for any `Tool` specified in the request. Refer to the
    /// [Function calling
    /// guide](https://ai.google.dev/gemini-api/docs/function-calling#function_calling_mode)
    /// for a usage example.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Tool config. This config is shared for all tools provided in the request.
    package let toolConfig: ToolConfig?
    
    /// Optional. A list of unique `SafetySetting` instances for blocking unsafe content.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. A list of unique `SafetySetting` instances for blocking unsafe content.
    /// 
    /// This will be enforced on the `GenerateContentRequest.contents` and
    /// `GenerateContentResponse.candidates`. There should not be more than one
    /// setting for each `SafetyCategory` type. The API will block any contents and
    /// responses that fail to meet the thresholds set by these settings. This list
    /// overrides the default settings for each `SafetyCategory` specified in the
    /// safety_settings. If there is no `SafetySetting` for a given
    /// `SafetyCategory` provided in the list, the API will use the default safety
    /// setting for that category. Harm categories HARM_CATEGORY_HATE_SPEECH,
    /// HARM_CATEGORY_SEXUALLY_EXPLICIT, HARM_CATEGORY_DANGEROUS_CONTENT,
    /// HARM_CATEGORY_HARASSMENT, HARM_CATEGORY_CIVIC_INTEGRITY,
    /// HARM_CATEGORY_JAILBREAK are supported.
    /// Refer to the [guide](https://ai.google.dev/gemini-api/docs/safety-settings)
    /// for detailed information on available safety settings. Also refer to the
    /// [Safety guidance](https://ai.google.dev/gemini-api/docs/safety-guidance) to
    /// learn how to incorporate safety considerations in your AI applications.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Per request settings for blocking unsafe content.
    /// Enforced on GenerateContentResponse.candidates.
    package let safetySettings: [SafetySetting]?
    
    /// Optional. Configuration options for model generation and outputs.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Configuration options for model generation and outputs.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Generation config.
    package let generationConfig: GenerationConfig?
    
    /// Optional. The name of the content
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The name of the content
    /// [cached](https://ai.google.dev/gemini-api/docs/caching) to use as context
    /// to serve the prediction. Format: `cachedContents/{cachedContent}`
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The name of the cached content used as context to serve the prediction.
    /// Note: only used in explicit caching, where users can have control over
    /// caching (e.g. what content to cache) and enjoy guaranteed cost savings.
    /// Format:
    /// `projects/{project}/locations/{location}/cachedContents/{cachedContent}`
    package let cachedContent: String?
    
    /// Optional. The service tier of the request.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The service tier of the request.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let serviceTier: ServiceTier?
    
    /// Optional. Configures the logging behavior for a given request. If set, it takes
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Configures the logging behavior for a given request. If set, it takes
    /// precedence over the project-level logging config.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let store: Bool?
    
    /// Optional. The labels with user-defined metadata for the request. It is used for
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The labels with user-defined metadata for the request. It is used for
    /// billing and reporting only.
    /// 
    /// Label keys and values can be no longer than 63 characters
    /// (Unicode codepoints) and can only contain lowercase letters, numeric
    /// characters, underscores, and dashes. International characters are allowed.
    /// Label values are optional. Label keys must start with a letter.
    package let labels: [String: String]?
    
    /// Optional. Settings for prompt and response sanitization using the Model Armor
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Settings for prompt and response sanitization using the Model Armor
    /// service. If supplied, safety_settings must not be supplied.
    package let modelArmorConfig: ModelArmorConfig?
    

    /// Creates a new `GenerateContentRequest`.
    ///
    /// - Parameters:
    ///   - model: Required. The name of the `Model` to use for generating the completion. (Gemini Developer API only). For more details, see ``model``.
    ///   - systemInstruction: Optional. Developer set [system (behavior varies by backend). For more details, see ``systemInstruction``.
    ///   - contents: Required. The content of the current conversation with the model. (behavior varies by backend). For more details, see ``contents``.
    ///   - tools: Optional. A list of `Tools` the `Model` may use to generate the next response. (behavior varies by backend). For more details, see ``tools``.
    ///   - toolConfig: Optional. Tool configuration for any `Tool` specified in the request. Refer to the (behavior varies by backend). For more details, see ``toolConfig``.
    ///   - safetySettings: Optional. A list of unique `SafetySetting` instances for blocking unsafe content. (behavior varies by backend). For more details, see ``safetySettings``.
    ///   - generationConfig: Optional. Configuration options for model generation and outputs. (behavior varies by backend). For more details, see ``generationConfig``.
    ///   - cachedContent: Optional. The name of the content (behavior varies by backend). For more details, see ``cachedContent``.
    ///   - serviceTier: Optional. The service tier of the request. (Gemini Developer API only). For more details, see ``serviceTier``.
    ///   - store: Optional. Configures the logging behavior for a given request. If set, it takes (Gemini Developer API only). For more details, see ``store``.
    ///   - labels: Optional. The labels with user-defined metadata for the request. It is used for (Gemini Enterprise Agent Platform only). For more details, see ``labels``.
    ///   - modelArmorConfig: Optional. Settings for prompt and response sanitization using the Model Armor (Gemini Enterprise Agent Platform only). For more details, see ``modelArmorConfig``.
    package init(
      model: String? = nil,
      systemInstruction: Content? = nil,
      contents: [Content],
      tools: [Tool]? = nil,
      toolConfig: ToolConfig? = nil,
      safetySettings: [SafetySetting]? = nil,
      generationConfig: GenerationConfig? = nil,
      cachedContent: String? = nil,
      serviceTier: ServiceTier? = nil,
      store: Bool? = nil,
      labels: [String: String]? = nil,
      modelArmorConfig: ModelArmorConfig? = nil
    ) {
      self.model = model
      self.systemInstruction = systemInstruction
      self.contents = contents
      self.tools = tools
      self.toolConfig = toolConfig
      self.safetySettings = safetySettings
      self.generationConfig = generationConfig
      self.cachedContent = cachedContent
      self.serviceTier = serviceTier
      self.store = store
      self.labels = labels
      self.modelArmorConfig = modelArmorConfig
    }
    enum CodingKeys: String, CodingKey {
      case model = "model"
      case systemInstruction = "systemInstruction"
      case contents = "contents"
      case tools = "tools"
      case toolConfig = "toolConfig"
      case safetySettings = "safetySettings"
      case generationConfig = "generationConfig"
      case cachedContent = "cachedContent"
      case serviceTier = "serviceTier"
      case store = "store"
      case labels = "labels"
      case modelArmorConfig = "modelArmorConfig"
    }
  }
}