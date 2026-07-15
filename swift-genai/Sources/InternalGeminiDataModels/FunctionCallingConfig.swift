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


extension GeminiDataModels {
  /// An internal data model for `FunctionCallingConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaFunctionCallingConfig`
  /// 
  /// Configuration for specifying function calling behavior.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1FunctionCallingConfig`
  /// 
  /// Function calling config.
  package struct FunctionCallingConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Specifies the mode in which function calling should execute. If
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Specifies the mode in which function calling should execute. If
    /// unspecified, the default value will be set to AUTO.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Function calling mode.
    package let mode: Mode?
    
    /// Optional. A set of function names that, when provided, limits the functions the model
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. A set of function names that, when provided, limits the functions the model
    /// will call.
    /// 
    /// This should only be set when the Mode is ANY or VALIDATED. Function names
    /// should match [FunctionDeclaration.name]. When set, model will
    /// predict a function call from only allowed function names.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Function names to call. Only set when the Mode is ANY. Function names
    /// should match FunctionDeclaration.name. With mode set to ANY, model will
    /// predict a function call from the set of function names provided.
    package let allowedFunctionNames: [String]?
    
    /// Optional. When set to true, arguments of a single function call will be streamed out
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. When set to true, arguments of a single function call will be streamed out
    /// in multiple parts/contents/responses. Partial parameter results will be
    /// returned in the `FunctionCall.partial_args` field.
    package let streamFunctionCallArguments: Bool?
    

    /// Creates a new `FunctionCallingConfig`.
    ///
    /// - Parameters:
    ///   - mode: Optional. Specifies the mode in which function calling should execute. If (behavior varies by backend). For more details, see ``mode``.
    ///   - allowedFunctionNames: Optional. A set of function names that, when provided, limits the functions the model (behavior varies by backend). For more details, see ``allowedFunctionNames``.
    ///   - streamFunctionCallArguments: Optional. When set to true, arguments of a single function call will be streamed out (Gemini Enterprise Agent Platform only). For more details, see ``streamFunctionCallArguments``.
    package init(
      mode: Mode? = nil,
      allowedFunctionNames: [String]? = nil,
      streamFunctionCallArguments: Bool? = nil
    ) {
      self.mode = mode
      self.allowedFunctionNames = allowedFunctionNames
      self.streamFunctionCallArguments = streamFunctionCallArguments
    }
    enum CodingKeys: String, CodingKey {
      case mode = "mode"
      case allowedFunctionNames = "allowedFunctionNames"
      case streamFunctionCallArguments = "streamFunctionCallArguments"
    }
  }
}