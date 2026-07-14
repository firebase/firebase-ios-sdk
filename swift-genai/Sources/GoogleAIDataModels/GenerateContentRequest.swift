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


extension GoogleAI {
  /// Request to generate a completion from the model.
  public struct GenerateContentRequest: Codable, Sendable, Equatable, Hashable {
    /// Optional. The name of the content [cached](https://ai.google.dev/gemini-api/docs/caching) to use as context to serve the prediction. Format: `cachedContents/{cachedContent}`
    public var cachedContent: String?
    
    /// Required. The content of the current conversation with the model. For single-turn queries, this is a single instance. For multi-turn queries like [chat](https://ai.google.dev/gemini-api/docs/text-generation#chat), this is a repeated field that contains the conversation history and the latest request.
    public var contents: [Content]?
    
    /// Optional. Configuration options for model generation and outputs.
    public var generationConfig: GenerationConfig?
    
    /// Required. The name of the `Model` to use for generating the completion. Format: `models/{model}`.
    public var model: String?
    
    /// Optional. A list of unique `SafetySetting` instances for blocking unsafe content. This will be enforced on the `GenerateContentRequest.contents` and `GenerateContentResponse.candidates`. There should not be more than one setting for each `SafetyCategory` type. The API will block any contents and responses that fail to meet the thresholds set by these settings. This list overrides the default settings for each `SafetyCategory` specified in the safety_settings. If there is no `SafetySetting` for a given `SafetyCategory` provided in the list, the API will use the default safety setting for that category. Harm categories HARM_CATEGORY_HATE_SPEECH, HARM_CATEGORY_SEXUALLY_EXPLICIT, HARM_CATEGORY_DANGEROUS_CONTENT, HARM_CATEGORY_HARASSMENT, HARM_CATEGORY_CIVIC_INTEGRITY, HARM_CATEGORY_JAILBREAK are supported. Refer to the [guide](https://ai.google.dev/gemini-api/docs/safety-settings) for detailed information on available safety settings. Also refer to the [Safety guidance](https://ai.google.dev/gemini-api/docs/safety-guidance) to learn how to incorporate safety considerations in your AI applications.
    public var safetySettings: [SafetySetting]?
    
    /// Optional. The service tier of the request.
    public var serviceTier: ServiceTier?
    
    /// Optional. Configures the logging behavior for a given request. If set, it takes precedence over the project-level logging config.
    public var store: Bool?
    
    /// Optional. Developer set [system instruction(s)](https://ai.google.dev/gemini-api/docs/system-instructions). Currently, text only.
    public var systemInstruction: Content?
    
    /// Optional. Tool configuration for any `Tool` specified in the request. Refer to the [Function calling guide](https://ai.google.dev/gemini-api/docs/function-calling#function_calling_mode) for a usage example.
    public var toolConfig: ToolConfig?
    
    /// Optional. A list of `Tools` the `Model` may use to generate the next response. A `Tool` is a piece of code that enables the system to interact with external systems to perform an action, or set of actions, outside of knowledge and scope of the `Model`. Supported `Tool`s are `Function` and `code_execution`. Refer to the [Function calling](https://ai.google.dev/gemini-api/docs/function-calling) and the [Code execution](https://ai.google.dev/gemini-api/docs/code-execution) guides to learn more.
    public var tools: [Tool]?
    
    /// Creates a new `GenerateContentRequest`.
    public init(
      cachedContent: String? = nil,
      contents: [Content]? = nil,
      generationConfig: GenerationConfig? = nil,
      model: String? = nil,
      safetySettings: [SafetySetting]? = nil,
      serviceTier: ServiceTier? = nil,
      store: Bool? = nil,
      systemInstruction: Content? = nil,
      toolConfig: ToolConfig? = nil,
      tools: [Tool]? = nil
    ) {
      self.cachedContent = cachedContent
      self.contents = contents
      self.generationConfig = generationConfig
      self.model = model
      self.safetySettings = safetySettings
      self.serviceTier = serviceTier
      self.store = store
      self.systemInstruction = systemInstruction
      self.toolConfig = toolConfig
      self.tools = tools
    }
    enum CodingKeys: String, CodingKey {
      case cachedContent = "cachedContent"
      case contents = "contents"
      case generationConfig = "generationConfig"
      case model = "model"
      case safetySettings = "safetySettings"
      case serviceTier = "serviceTier"
      case store = "store"
      case systemInstruction = "systemInstruction"
      case toolConfig = "toolConfig"
      case tools = "tools"
    }
  }
}