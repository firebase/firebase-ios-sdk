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

extension AgentPlatform.FunctionResponse {
  /// Optional. Specifies how the response should be scheduled in the conversation. Only applicable to NON_BLOCKING function calls, is ignored otherwise. Defaults to WHEN_IDLE.
  package enum Scheduling: Codable, Sendable, Equatable, Hashable {
    /// Only add the result to the conversation context, do not interrupt or trigger generation.
    case silent
    
    /// Add the result to the conversation context, and prompt to generate output without interrupting ongoing generation.
    case whenIdle
    
    /// Add the result to the conversation context, interrupt ongoing generation and prompt to generate output.
    case interrupt
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.FunctionResponse.Scheduling: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .silent: "SILENT"
    case .whenIdle: "WHEN_IDLE"
    case .interrupt: "INTERRUPT"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "SILENT": self = .silent
    case "WHEN_IDLE": self = .whenIdle
    case "INTERRUPT": self = .interrupt
    default: self = .unrecognized(rawValue)
    }
  }
}