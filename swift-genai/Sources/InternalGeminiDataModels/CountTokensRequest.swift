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
  /// Counts the number of tokens in the `prompt` sent to a model. Models may tokenize text differently, so each model may return a different `token_count`.
  /// 
  /// Variant:
  /// Request message for PredictionService.CountTokens.
  package struct CountTokensRequest: Codable, Sendable, Equatable, Hashable {
    /// Optional. Generation config that the model will use to generate the response.
    /// 
    /// > Important: `generationConfig` is only available in the Gemini Enterprise Agent Platform.
    package let generationConfig: GenerationConfig?
    
    /// Optional. The name of the publisher model requested to serve the prediction. Format: `projects/{project}/locations/{location}/publishers/*/models/*`
    /// 
    /// > Important: `model` is only available in the Gemini Enterprise Agent Platform.
    package let model: String?
    
    /// Optional. The input given to the model as a prompt. This field is ignored when `generate_content_request` is set.
    /// 
    /// Variant:
    /// Optional. Input content.
    package let contents: [Content]?
    
    /// Optional. The user provided system instructions for the model. Note: only text should be used in parts and content in each part will be in a separate paragraph.
    /// 
    /// > Important: `systemInstruction` is only available in the Gemini Enterprise Agent Platform.
    package let systemInstruction: Content?
    
    /// Optional. The instances that are the input to token counting call. Schema is identical to the prediction schema of the underlying model.
    /// 
    /// > Important: `instances` is only available in the Gemini Enterprise Agent Platform.
    package let instances: [JSONValue]?
    
    /// Optional. A list of `Tools` the model may use to generate the next response. A `Tool` is a piece of code that enables the system to interact with external systems to perform an action, or set of actions, outside of knowledge and scope of the model.
    /// 
    /// > Important: `tools` is only available in the Gemini Enterprise Agent Platform.
    package let tools: [Tool]?
    
    /// Optional. The overall input given to the `Model`. This includes the prompt as well as other model steering information like [system instructions](https://ai.google.dev/gemini-api/docs/system-instructions), and/or function declarations for [function calling](https://ai.google.dev/gemini-api/docs/function-calling). `Model`s/`Content`s and `generate_content_request`s are mutually exclusive. You can either send `Model` + `Content`s or a `generate_content_request`, but never both.
    /// 
    /// > Important: `generateContentRequest` is only available in the Gemini Developer API.
    package let generateContentRequest: GenerateContentRequest?
    
    /// Creates a new `CountTokensRequest`.
    package init(
      generationConfig: GenerationConfig? = nil,
      model: String? = nil,
      contents: [Content]? = nil,
      systemInstruction: Content? = nil,
      instances: [JSONValue]? = nil,
      tools: [Tool]? = nil,
      generateContentRequest: GenerateContentRequest? = nil
    ) {
      self.generationConfig = generationConfig
      self.model = model
      self.contents = contents
      self.systemInstruction = systemInstruction
      self.instances = instances
      self.tools = tools
      self.generateContentRequest = generateContentRequest
    }
    enum CodingKeys: String, CodingKey {
      case generationConfig = "generationConfig"
      case model = "model"
      case contents = "contents"
      case systemInstruction = "systemInstruction"
      case instances = "instances"
      case tools = "tools"
      case generateContentRequest = "generateContentRequest"
    }
  }
}