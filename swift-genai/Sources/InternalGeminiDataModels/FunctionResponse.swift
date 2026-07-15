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
  /// An internal data model for `FunctionResponse`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `FunctionResponse`
  /// 
  /// An element in the history that represents the results of a function
  /// invocation.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1FunctionResponse`
  /// 
  /// The result output from a FunctionCall that contains
  /// a string representing the FunctionDeclaration.name and a structured
  /// JSON object containing any output from the function is used as context to
  /// the model. This should contain the result of a `FunctionCall` made based
  /// on model prediction.
  package struct FunctionResponse: Codable, Sendable, Equatable, Hashable {
    /// Required. ID of the individual function invocation assigned by the model when it
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. ID of the individual function invocation assigned by the model when it
    /// requests the function invocation.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The id of the function call this response is for. Populated by the client
    /// to match the corresponding function call `id`.
    package let id: String
    
    /// Required. The name of the function.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The name of the function.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The name of the function to call.
    /// Matches FunctionDeclaration.name and FunctionCall.name.
    package let name: String
    
    /// Optional. The results of the function invocation.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The results of the function invocation.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The function response in JSON object format.
    /// Use "output" key to specify function output and "error" key to specify
    /// error details (if any). If "output" and "error" keys are not specified,
    /// then whole "response" is treated as function output.
    package let response: [String: JSONValue]?
    
    /// Optional. Ordered `Parts` that constitute a function response. Parts may have
    /// different IANA MIME types.
    package let parts: [FunctionResponsePart]?
    
    /// Optional. Signals that function call continues, and more responses will be
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Signals that function call continues, and more responses will be
    /// returned, turning the function call into a generator.
    /// Is only applicable to NON_BLOCKING function calls, is ignored otherwise.
    /// If set to false, future responses will not be considered.
    /// It is allowed to return empty `response` with `will_continue=False` to
    /// signal that the function call is finished. This may still trigger the model
    /// generation. To avoid triggering the generation and finish the function
    /// call, additionally set `scheduling` to `SILENT`.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let willContinue: Bool?
    
    /// Optional. Specifies how the response should be scheduled in the conversation.
    /// Only applicable to NON_BLOCKING function calls, is ignored otherwise.
    /// Defaults to WHEN_IDLE.
    package let scheduling: Scheduling?
    

    /// Creates a new `FunctionResponse`.
    ///
    /// - Parameters:
    ///   - id: Required. ID of the individual function invocation assigned by the model when it (behavior varies by backend). For more details, see ``id``.
    ///   - name: Required. The name of the function. (behavior varies by backend). For more details, see ``name``.
    ///   - response: Optional. The results of the function invocation. (behavior varies by backend). For more details, see ``response``.
    ///   - parts: Optional. Ordered `Parts` that constitute a function response. Parts may have
    ///   - willContinue: Optional. Signals that function call continues, and more responses will be (Gemini Developer API only). For more details, see ``willContinue``.
    ///   - scheduling: Optional. Specifies how the response should be scheduled in the conversation.
    package init(
      id: String,
      name: String,
      response: [String: JSONValue]? = nil,
      parts: [FunctionResponsePart]? = nil,
      willContinue: Bool? = nil,
      scheduling: Scheduling? = nil
    ) {
      self.id = id
      self.name = name
      self.response = response
      self.parts = parts
      self.willContinue = willContinue
      self.scheduling = scheduling
    }
    enum CodingKeys: String, CodingKey {
      case id = "id"
      case name = "name"
      case response = "response"
      case parts = "parts"
      case willContinue = "willContinue"
      case scheduling = "scheduling"
    }
  }
}