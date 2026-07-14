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
  /// An element in the history the represents the model asking the client to invoke a client-side function.
  /// 
  /// Variant:
  /// A predicted FunctionCall returned from the model that contains a string representing the FunctionDeclaration.name and a structured JSON object containing the parameters and their values.
  package struct FunctionCall: Codable, Sendable, Equatable, Hashable {
    /// Required. The name of the function to be invoked.
    /// 
    /// Variant:
    /// Optional. The name of the function to call. Matches FunctionDeclaration.name.
    package let name: String?
    
    /// Optional. The partial argument value of the function call. If provided, represents the arguments/fields that are streamed incrementally.
    /// 
    /// > Important: `partialArgs` is only available in the Gemini Enterprise Agent Platform.
    package let partialArgs: [PartialArg]?
    
    /// Required. ID of the individual function invocation assigned by the model when it requests the function invocation.
    /// 
    /// Variant:
    /// Optional. The unique id of the function call. If populated, the client to execute the `function_call` and return the response with the matching `id`.
    package let id: String?
    
    /// Optional. Whether this is the last part of the FunctionCall. If true, another partial message for the current FunctionCall is expected to follow.
    /// 
    /// > Important: `willContinue` is only available in the Gemini Enterprise Agent Platform.
    package let willContinue: Bool?
    
    /// Optional. Inputs to the function passed by the model
    /// 
    /// Variant:
    /// Optional. The function parameters and values in JSON object format. See FunctionDeclaration.parameters for parameter details.
    package let args: [String: JSONValue]?
    
    /// Creates a new `FunctionCall`.
    package init(
      name: String? = nil,
      partialArgs: [PartialArg]? = nil,
      id: String? = nil,
      willContinue: Bool? = nil,
      args: [String: JSONValue]? = nil
    ) {
      self.name = name
      self.partialArgs = partialArgs
      self.id = id
      self.willContinue = willContinue
      self.args = args
    }
    enum CodingKeys: String, CodingKey {
      case name = "name"
      case partialArgs = "partialArgs"
      case id = "id"
      case willContinue = "willContinue"
      case args = "args"
    }
  }
}