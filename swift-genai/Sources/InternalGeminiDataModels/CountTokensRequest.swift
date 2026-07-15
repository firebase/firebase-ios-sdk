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
package import InternalSharedDataModels


extension GeminiDataModels {
  /// An internal data model for `CountTokensRequest`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaCountTokensRequest`
  /// 
  /// Counts the number of tokens in the `prompt` sent to a model.
  /// 
  /// Models may tokenize text differently, so each model may return a different
  /// `token_count`.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1CountTokensRequest`
  /// 
  /// Request message for PredictionService.CountTokens.
  package struct CountTokensRequest: Codable, Sendable, Equatable, Hashable {
    /// Optional. The input given to the model as a prompt. This field is ignored when
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The input given to the model as a prompt. This field is ignored when
    /// `generate_content_request` is set.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Input content.
    package let contents: [Content]?
    
    /// Optional. The overall input given to the `Model`. This includes the prompt as well as
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The overall input given to the `Model`. This includes the prompt as well as
    /// other model steering information like [system
    /// instructions](https://ai.google.dev/gemini-api/docs/system-instructions),
    /// and/or function declarations for [function
    /// calling](https://ai.google.dev/gemini-api/docs/function-calling).
    /// `Model`s/`Content`s and `generate_content_request`s are mutually
    /// exclusive. You can either send `Model` + `Content`s or a
    /// `generate_content_request`, but never both.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let generateContentRequest: GenerateContentRequest?
    
    /// Optional. The name of the publisher model requested to serve the prediction.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The name of the publisher model requested to serve the prediction.
    /// Format:
    /// `projects/{project}/locations/{location}/publishers/*/models/*`
    package let model: String?
    
    /// Optional. The instances that are the input to token counting call.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The instances that are the input to token counting call.
    /// Schema is identical to the prediction schema of the underlying model.
    package let instances: [JSONValue]?
    
    /// Optional. The user provided system instructions for the model.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The user provided system instructions for the model.
    /// Note: only text should be used in parts and content in each part will be in
    /// a separate paragraph.
    package let systemInstruction: Content?
    
    /// Optional. A list of `Tools` the model may use to generate the next response.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. A list of `Tools` the model may use to generate the next response.
    /// 
    /// A `Tool` is a piece of code that enables the system to interact with
    /// external systems to perform an action, or set of actions, outside of
    /// knowledge and scope of the model.
    package let tools: [Tool]?
    
    /// Optional. Generation config that the model will use to generate the response.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Generation config that the model will use to generate the response.
    package let generationConfig: GenerationConfig?
    

    /// Creates a new `CountTokensRequest`.
    ///
    /// - Parameters:
    ///   - contents: Optional. The input given to the model as a prompt. This field is ignored when (behavior varies by backend). For more details, see ``contents``.
    ///   - generateContentRequest: Optional. The overall input given to the `Model`. This includes the prompt as well as (Gemini Developer API only). For more details, see ``generateContentRequest``.
    ///   - model: Optional. The name of the publisher model requested to serve the prediction. (Gemini Enterprise Agent Platform only). For more details, see ``model``.
    ///   - instances: Optional. The instances that are the input to token counting call. (Gemini Enterprise Agent Platform only). For more details, see ``instances``.
    ///   - systemInstruction: Optional. The user provided system instructions for the model. (Gemini Enterprise Agent Platform only). For more details, see ``systemInstruction``.
    ///   - tools: Optional. A list of `Tools` the model may use to generate the next response. (Gemini Enterprise Agent Platform only). For more details, see ``tools``.
    ///   - generationConfig: Optional. Generation config that the model will use to generate the response. (Gemini Enterprise Agent Platform only). For more details, see ``generationConfig``.
    package init(
      contents: [Content]? = nil,
      generateContentRequest: GenerateContentRequest? = nil,
      model: String? = nil,
      instances: [JSONValue]? = nil,
      systemInstruction: Content? = nil,
      tools: [Tool]? = nil,
      generationConfig: GenerationConfig? = nil
    ) {
      self.contents = contents
      self.generateContentRequest = generateContentRequest
      self.model = model
      self.instances = instances
      self.systemInstruction = systemInstruction
      self.tools = tools
      self.generationConfig = generationConfig
    }
    enum CodingKeys: String, CodingKey {
      case contents = "contents"
      case generateContentRequest = "generateContentRequest"
      case model = "model"
      case instances = "instances"
      case systemInstruction = "systemInstruction"
      case tools = "tools"
      case generationConfig = "generationConfig"
    }
  }
}