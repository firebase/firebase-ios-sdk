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
package import InternalGoogleAIDataModels
package import InternalAgentPlatformDataModels

/// Represents a result of code execution.
public struct CodeExecutionResult: Codable, Sendable, Equatable, Hashable {
  public var outcome: Outcome?
  public var output: String?
  /// - Note: Only supported on GoogleAI backend.
  public var id: String?

  public init(outcome: Outcome? = nil, output: String? = nil, id: String? = nil) {
    self.outcome = outcome
    self.output = output
    self.id = id
  }
}

public enum Outcome: Codable, Sendable, Equatable, Hashable {
  case ok
  case failed
  case deadlineExceeded
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension CodeExecutionResult {
  package func toGoogleAI() -> GoogleAI.CodeExecutionResult {
    GoogleAI.CodeExecutionResult(id: id, outcome: outcome?.toGoogleAI(), output: output)
  }

  package init(fromGoogleAI cer: GoogleAI.CodeExecutionResult) {
    self.outcome = cer.outcome.map { Outcome(fromGoogleAI: $0) }
    self.output = cer.output
    self.id = cer.id
  }
}

extension Outcome {
  package func toGoogleAI() -> GoogleAI.CodeExecutionResult.Outcome {
    switch self {
    case .ok: .ok
    case .failed: .failed
    case .deadlineExceeded: .deadlineExceeded
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI out: GoogleAI.CodeExecutionResult.Outcome) {
    switch out {
    case .ok: self = .ok
    case .failed: self = .failed
    case .deadlineExceeded: self = .deadlineExceeded
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension CodeExecutionResult {
  package func toAgentPlatform() -> AgentPlatform.CodeExecutionResult {
    AgentPlatform.CodeExecutionResult(outcome: outcome?.toAgentPlatform(), output: output)
  }

  package init(fromAgentPlatform cer: AgentPlatform.CodeExecutionResult) {
    self.outcome = cer.outcome.map { Outcome(fromAgentPlatform: $0) }
    self.output = cer.output
    self.id = nil
  }
}

extension Outcome {
  package func toAgentPlatform() -> AgentPlatform.CodeExecutionResult.Outcome {
    switch self {
    case .ok: .ok
    case .failed: .failed
    case .deadlineExceeded: .deadlineExceeded
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform out: AgentPlatform.CodeExecutionResult.Outcome) {
    switch out {
    case .ok: self = .ok
    case .failed: self = .failed
    case .deadlineExceeded: self = .deadlineExceeded
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}
