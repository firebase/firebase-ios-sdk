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


extension GoogleAI {
  /// Configuration for specifying function calling behavior.
  package struct FunctionCallingConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. A set of function names that, when provided, limits the functions the model will call. This should only be set when the Mode is ANY or VALIDATED. Function names should match [FunctionDeclaration.name]. When set, model will predict a function call from only allowed function names.
    package var allowedFunctionNames: [String]?
    
    /// Optional. Specifies the mode in which function calling should execute. If unspecified, the default value will be set to AUTO.
    package var mode: Mode?
    
    /// Creates a new `FunctionCallingConfig`.
    package init(
      allowedFunctionNames: [String]? = nil,
      mode: Mode? = nil
    ) {
      self.allowedFunctionNames = allowedFunctionNames
      self.mode = mode
    }
    enum CodingKeys: String, CodingKey {
      case allowedFunctionNames = "allowedFunctionNames"
      case mode = "mode"
    }
  }
}