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


extension AgentPlatform {
  /// Function calling config.
  package struct FunctionCallingConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Function names to call. Only set when the Mode is ANY. Function names should match FunctionDeclaration.name. With mode set to ANY, model will predict a function call from the set of function names provided.
    package var allowedFunctionNames: [String]?
    
    /// Optional. Function calling mode.
    package var mode: Mode?
    
    /// Optional. When set to true, arguments of a single function call will be streamed out in multiple parts/contents/responses. Partial parameter results will be returned in the `FunctionCall.partial_args` field.
    package var streamFunctionCallArguments: Bool?
    
    /// Creates a new `FunctionCallingConfig`.
    package init(
      allowedFunctionNames: [String]? = nil,
      mode: Mode? = nil,
      streamFunctionCallArguments: Bool? = nil
    ) {
      self.allowedFunctionNames = allowedFunctionNames
      self.mode = mode
      self.streamFunctionCallArguments = streamFunctionCallArguments
    }
    enum CodingKeys: String, CodingKey {
      case allowedFunctionNames = "allowedFunctionNames"
      case mode = "mode"
      case streamFunctionCallArguments = "streamFunctionCallArguments"
    }
  }
}