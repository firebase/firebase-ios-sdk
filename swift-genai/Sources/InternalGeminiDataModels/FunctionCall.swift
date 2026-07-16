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
  /// An internal data model for `FunctionCall`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `FunctionCall`
  /// 
  /// An element in the history the represents the model asking the client to
  /// invoke a client-side function.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1FunctionCall`
  /// 
  /// A predicted FunctionCall returned from the model that
  /// contains a string representing the FunctionDeclaration.name and
  /// a structured JSON object containing the parameters and their values.
  package struct FunctionCall: Codable, Sendable, Equatable, Hashable {
    /// Required. ID of the individual function invocation assigned by the model when it
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. ID of the individual function invocation assigned by the model when it
    /// requests the function invocation.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The unique id of the function call. If populated, the client to execute the
    /// `function_call` and return the response with the matching `id`.
    package let id: String?
    
    /// Required. The name of the function to be invoked.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The name of the function to be invoked.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The name of the function to call.
    /// Matches FunctionDeclaration.name.
    package let name: String
    
    /// Optional. Inputs to the function passed by the model
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Inputs to the function passed by the model
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The function parameters and values in JSON object format.
    /// See FunctionDeclaration.parameters for parameter details.
    package let args: [String: JSONValue]?
    
    /// Optional. Whether this is the last part of the FunctionCall.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Whether this is the last part of the FunctionCall.
    /// If true, another partial message for the current FunctionCall is expected
    /// to follow.
    package let willContinue: Bool?
    

    /// Creates a new `FunctionCall`.
    ///
    /// - Parameters:
    ///   - id: Required. ID of the individual function invocation assigned by the model when it (behavior varies by backend). For more details, see ``id``.
    ///   - name: Required. The name of the function to be invoked. (behavior varies by backend). For more details, see ``name``.
    ///   - args: Optional. Inputs to the function passed by the model (behavior varies by backend). For more details, see ``args``.
    ///   - willContinue: Optional. Whether this is the last part of the FunctionCall. (Gemini Enterprise Agent Platform only). For more details, see ``willContinue``.
    package init(
      id: String? = nil,
      name: String,
      args: [String: JSONValue]? = nil,
      willContinue: Bool? = nil
    ) {
      self.id = id
      self.name = name
      self.args = args
      self.willContinue = willContinue
    }
    enum CodingKeys: String, CodingKey {
      case id = "id"
      case name = "name"
      case args = "args"
      case willContinue = "willContinue"
    }
  }
}