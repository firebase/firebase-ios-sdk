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
  /// The result output from a FunctionCall that contains a string representing the FunctionDeclaration.name and a structured JSON object containing any output from the function is used as context to the model. This should contain the result of a `FunctionCall` made based on model prediction.
  public struct FunctionResponse: Codable, Sendable, Equatable, Hashable {
    /// Optional. The id of the function call this response is for. Populated by the client to match the corresponding function call `id`.
    public var id: String?
    
    /// Required. The name of the function to call. Matches FunctionDeclaration.name and FunctionCall.name.
    public var name: String?
    
    /// Optional. Ordered `Parts` that constitute a function response. Parts may have different IANA MIME types.
    public var parts: [FunctionResponsePart]?
    
    /// Required. The function response in JSON object format. Use "output" key to specify function output and "error" key to specify error details (if any). If "output" and "error" keys are not specified, then whole "response" is treated as function output.
    public var response: [String: JSONValue]?
    
    /// Optional. Specifies how the response should be scheduled in the conversation. Only applicable to NON_BLOCKING function calls, is ignored otherwise. Defaults to WHEN_IDLE.
    public var scheduling: Scheduling?
    
    /// Creates a new `FunctionResponse`.
    public init(
      id: String? = nil,
      name: String? = nil,
      parts: [FunctionResponsePart]? = nil,
      response: [String: JSONValue]? = nil,
      scheduling: Scheduling? = nil
    ) {
      self.id = id
      self.name = name
      self.parts = parts
      self.response = response
      self.scheduling = scheduling
    }
    enum CodingKeys: String, CodingKey {
      case id = "id"
      case name = "name"
      case parts = "parts"
      case response = "response"
      case scheduling = "scheduling"
    }
  }
}