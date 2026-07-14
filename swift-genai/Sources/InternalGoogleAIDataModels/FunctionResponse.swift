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


extension GoogleAI {
  /// The result output from a `FunctionCall` that contains a string representing the `FunctionDeclaration.name` and a structured JSON object containing any output from the function is used as context to the model. This should contain the result of a`FunctionCall` made based on model prediction.
  public struct FunctionResponse: Codable, Sendable, Equatable, Hashable {
    /// Optional. The identifier of the function call this response is for. Populated by the client to match the corresponding function call `id`.
    public var id: String?
    
    /// Required. The name of the function to call. Must be a-z, A-Z, 0-9, or contain underscores and dashes, with a maximum length of 128.
    public var name: String?
    
    /// Optional. Ordered `Parts` that constitute a function response. Parts may have different IANA MIME types.
    public var parts: [FunctionResponsePart]?
    
    /// Required. The function response in JSON object format. Callers can use any keys of their choice that fit the function's syntax to return the function output, e.g. "output", "result", etc. In particular, if the function call failed to execute, the response can have an "error" key to return error details to the model. Multimedia can be included by using a subobject containing a single "$ref" key whose value is the `inline_data.display_name` of a `FunctionResponsePart` holding the multimedia. See https://ai.google.dev/gemini-api/docs/function-calling#multimodal.
    public var response: [String: JSONValue]?
    
    /// Optional. Specifies how the response should be scheduled in the conversation. Only applicable to NON_BLOCKING function calls, is ignored otherwise. Defaults to WHEN_IDLE.
    public var scheduling: Scheduling?
    
    /// Optional. Signals that function call continues, and more responses will be returned, turning the function call into a generator. Is only applicable to NON_BLOCKING function calls, is ignored otherwise. If set to false, future responses will not be considered. It is allowed to return empty `response` with `will_continue=False` to signal that the function call is finished. This may still trigger the model generation. To avoid triggering the generation and finish the function call, additionally set `scheduling` to `SILENT`.
    public var willContinue: Bool?
    
    /// Creates a new `FunctionResponse`.
    public init(
      id: String? = nil,
      name: String? = nil,
      parts: [FunctionResponsePart]? = nil,
      response: [String: JSONValue]? = nil,
      scheduling: Scheduling? = nil,
      willContinue: Bool? = nil
    ) {
      self.id = id
      self.name = name
      self.parts = parts
      self.response = response
      self.scheduling = scheduling
      self.willContinue = willContinue
    }
    enum CodingKeys: String, CodingKey {
      case id = "id"
      case name = "name"
      case parts = "parts"
      case response = "response"
      case scheduling = "scheduling"
      case willContinue = "willContinue"
    }
  }
}