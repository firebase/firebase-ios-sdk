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
public import InternalSharedDataModels


extension AgentPlatform {
  /// A predicted FunctionCall returned from the model that contains a string representing the FunctionDeclaration.name and a structured JSON object containing the parameters and their values.
  public struct FunctionCall: Codable, Sendable, Equatable, Hashable {
    /// Optional. The function parameters and values in JSON object format. See FunctionDeclaration.parameters for parameter details.
    public var args: [String: JSONValue]?
    
    /// Optional. The unique id of the function call. If populated, the client to execute the `function_call` and return the response with the matching `id`.
    public var id: String?
    
    /// Optional. The name of the function to call. Matches FunctionDeclaration.name.
    public var name: String?
    
    /// Optional. The partial argument value of the function call. If provided, represents the arguments/fields that are streamed incrementally.
    public var partialArgs: [PartialArg]?
    
    /// Optional. Whether this is the last part of the FunctionCall. If true, another partial message for the current FunctionCall is expected to follow.
    public var willContinue: Bool?
    
    /// Creates a new `FunctionCall`.
    public init(
      args: [String: JSONValue]? = nil,
      id: String? = nil,
      name: String? = nil,
      partialArgs: [PartialArg]? = nil,
      willContinue: Bool? = nil
    ) {
      self.args = args
      self.id = id
      self.name = name
      self.partialArgs = partialArgs
      self.willContinue = willContinue
    }
    enum CodingKeys: String, CodingKey {
      case args = "args"
      case id = "id"
      case name = "name"
      case partialArgs = "partialArgs"
      case willContinue = "willContinue"
    }
  }
}