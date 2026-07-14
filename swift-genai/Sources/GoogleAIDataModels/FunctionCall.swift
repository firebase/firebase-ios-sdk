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
public import SharedDataModels


extension GoogleAI {
  /// A predicted `FunctionCall` returned from the model that contains a string representing the `FunctionDeclaration.name` with the arguments and their values.
  public struct FunctionCall: Codable, Sendable, Equatable, Hashable {
    /// Optional. The function parameters and values in JSON object format.
    public var args: [String: JSONValue]?
    
    /// Optional. Unique identifier of the function call. If populated, the client to execute the `function_call` and return the response with the matching `id`.
    public var id: String?
    
    /// Required. The name of the function to call. Must be a-z, A-Z, 0-9, or contain underscores and dashes, with a maximum length of 128.
    public var name: String?
    
    /// Creates a new `FunctionCall`.
    public init(
      args: [String: JSONValue]? = nil,
      id: String? = nil,
      name: String? = nil
    ) {
      self.args = args
      self.id = id
      self.name = name
    }
    enum CodingKeys: String, CodingKey {
      case args = "args"
      case id = "id"
      case name = "name"
    }
  }
}