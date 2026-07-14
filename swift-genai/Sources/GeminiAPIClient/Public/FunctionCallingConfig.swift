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

/// Configuration for specifying function calling behavior.
public struct FunctionCallingConfig: Codable, Sendable, Equatable, Hashable {
  public var allowedFunctionNames: [String]?
  public var mode: Mode?
  /// - Note: Only supported on AgentPlatform backend.
  public var streamFunctionCallArguments: Bool?

  public init(
    allowedFunctionNames: [String]? = nil,
    mode: Mode? = nil,
    streamFunctionCallArguments: Bool? = nil
  ) {
    self.allowedFunctionNames = allowedFunctionNames
    self.mode = mode
    self.streamFunctionCallArguments = streamFunctionCallArguments
  }
}

extension FunctionCallingConfig {
  public enum Mode: Codable, Sendable, Equatable, Hashable {
    case auto
    case `any`
    case none
    case validated
    case unrecognized(_ value: String)
  }
}

// MARK: - GoogleAI Mappings

extension FunctionCallingConfig {
  package func toGoogleAI() -> GoogleAI.FunctionCallingConfig {
    GoogleAI.FunctionCallingConfig(
      allowedFunctionNames: allowedFunctionNames,
      mode: mode?.toGoogleAI()
    )
  }

  package init(fromGoogleAI fc: GoogleAI.FunctionCallingConfig) {
    self.allowedFunctionNames = fc.allowedFunctionNames
    self.mode = fc.mode.map { Mode(fromGoogleAI: $0) }
    self.streamFunctionCallArguments = nil
  }
}

extension FunctionCallingConfig.Mode {
  package func toGoogleAI() -> GoogleAI.FunctionCallingConfig.Mode {
    switch self {
    case .auto: .auto
    case .`any`: .`any`
    case .none: .none
    case .validated: .validated
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI mode: GoogleAI.FunctionCallingConfig.Mode) {
    switch mode {
    case .auto: self = .auto
    case .`any`: self = .`any`
    case .none: self = .none
    case .validated: self = .validated
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension FunctionCallingConfig {
  package func toAgentPlatform() -> AgentPlatform.FunctionCallingConfig {
    AgentPlatform.FunctionCallingConfig(
      allowedFunctionNames: allowedFunctionNames,
      mode: mode?.toAgentPlatform(),
      streamFunctionCallArguments: streamFunctionCallArguments
    )
  }

  package init(fromAgentPlatform fc: AgentPlatform.FunctionCallingConfig) {
    self.allowedFunctionNames = fc.allowedFunctionNames
    self.mode = fc.mode.map { Mode(fromAgentPlatform: $0) }
    self.streamFunctionCallArguments = fc.streamFunctionCallArguments
  }
}

extension FunctionCallingConfig.Mode {
  package func toAgentPlatform() -> AgentPlatform.FunctionCallingConfig.Mode {
    switch self {
    case .auto: .auto
    case .`any`: .`any`
    case .none: .none
    case .validated: .validated
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform mode: AgentPlatform.FunctionCallingConfig.Mode) {
    switch mode {
    case .auto: self = .auto
    case .`any`: self = .`any`
    case .none: self = .none
    case .validated: self = .validated
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}
