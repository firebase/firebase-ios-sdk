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

extension AgentPlatform.FunctionDeclaration {
  /// Optional. Specifies the function Behavior. If not specified, the system keeps the current function call behavior. This field is currently only supported by the BidiGenerateContent method.
  package enum Behavior: Codable, Sendable, Equatable, Hashable {
    /// If set, the system will wait to receive the function response before continuing the conversation.
    case blocking
    
    /// If set, the system will not wait to receive the function response. Instead, it will attempt to handle function responses as they become available while maintaining the conversation between the user and the model.
    case nonBlocking
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.FunctionDeclaration.Behavior: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .blocking: "BLOCKING"
    case .nonBlocking: "NON_BLOCKING"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "BLOCKING": self = .blocking
    case "NON_BLOCKING": self = .nonBlocking
    default: self = .unrecognized(rawValue)
    }
  }
}