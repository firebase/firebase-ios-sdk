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

extension AgentPlatform.FunctionCallingConfig {
  /// Optional. Function calling mode.
  public enum Mode: Codable, Sendable, Equatable, Hashable {
    /// Default model behavior, model decides to predict either function calls or natural language response.
    case auto
    
    /// Model is constrained to always predicting function calls only. If "allowed_function_names" are set, the predicted function calls will be limited to any one of "allowed_function_names", else the predicted function calls will be any one of the provided "function_declarations".
    case `any`
    
    /// Model will not predict any function calls. Model behavior is same as when not passing any function declarations.
    case none
    
    /// Model is constrained to predict either function calls or natural language response. If "allowed_function_names" are set, the predicted function calls will be limited to any one of "allowed_function_names", else the predicted function calls will be any one of the provided "function_declarations".
    case validated
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.FunctionCallingConfig.Mode: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .auto: "AUTO"
    case .`any`: "ANY"
    case .none: "NONE"
    case .validated: "VALIDATED"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "AUTO": self = .auto
    case "ANY": self = .`any`
    case "NONE": self = .none
    case "VALIDATED": self = .validated
    default: self = .unrecognized(rawValue)
    }
  }
}