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
package import InternalGoogleAIDataModels
package import InternalAgentPlatformDataModels

/// Represents a function call.
public struct FunctionCall: Codable, Sendable, Equatable, Hashable {
  public var name: String?
  public var args: [String: JSONValue]?
  public var id: String?
  /// - Note: Only supported on AgentPlatform backend.
  public var partialArgs: [PartialArg]?
  /// - Note: Only supported on AgentPlatform backend.
  public var willContinue: Bool?

  public init(
    name: String? = nil,
    args: [String: JSONValue]? = nil,
    id: String? = nil,
    partialArgs: [PartialArg]? = nil,
    willContinue: Bool? = nil
  ) {
    self.name = name
    self.args = args
    self.id = id
    self.partialArgs = partialArgs
    self.willContinue = willContinue
  }
}

public struct PartialArg: Codable, Sendable, Equatable, Hashable {
  public var boolValue: Bool?
  public var jsonPath: String?
  public var nullValue: NullValue?
  public var numberValue: Double?
  public var stringValue: String?
  public var willContinue: Bool?

  public init(
    boolValue: Bool? = nil,
    jsonPath: String? = nil,
    nullValue: NullValue? = nil,
    numberValue: Double? = nil,
    stringValue: String? = nil,
    willContinue: Bool? = nil
  ) {
    self.boolValue = boolValue
    self.jsonPath = jsonPath
    self.nullValue = nullValue
    self.numberValue = numberValue
    self.stringValue = stringValue
    self.willContinue = willContinue
  }
}

public enum NullValue: Codable, Sendable, Equatable, Hashable {
  case value
}

// MARK: - GoogleAI Mappings

extension FunctionCall {
  package func toGoogleAI() -> GoogleAI.FunctionCall {
    GoogleAI.FunctionCall(args: args, id: id, name: name)
  }

  package init(fromGoogleAI fc: GoogleAI.FunctionCall) {
    self.name = fc.name
    self.args = fc.args
    self.id = fc.id
    self.partialArgs = nil
    self.willContinue = nil
  }
}

// MARK: - AgentPlatform Mappings

extension FunctionCall {
  package func toAgentPlatform() -> AgentPlatform.FunctionCall {
    AgentPlatform.FunctionCall(
      args: args,
      id: id,
      name: name,
      partialArgs: partialArgs?.map { $0.toAgentPlatform() },
      willContinue: willContinue
    )
  }

  package init(fromAgentPlatform fc: AgentPlatform.FunctionCall) {
    self.name = fc.name
    self.args = fc.args
    self.id = fc.id
    self.partialArgs = fc.partialArgs?.map { PartialArg(fromAgentPlatform: $0) }
    self.willContinue = fc.willContinue
  }
}

extension PartialArg {
  package func toAgentPlatform() -> AgentPlatform.PartialArg {
    AgentPlatform.PartialArg(
      boolValue: boolValue,
      jsonPath: jsonPath,
      nullValue: nullValue?.toAgentPlatform(),
      numberValue: numberValue,
      stringValue: stringValue,
      willContinue: willContinue
    )
  }

  package init(fromAgentPlatform pa: AgentPlatform.PartialArg) {
    self.boolValue = pa.boolValue
    self.jsonPath = pa.jsonPath
    self.nullValue = pa.nullValue.map { NullValue(fromAgentPlatform: $0) }
    self.numberValue = pa.numberValue
    self.stringValue = pa.stringValue
    self.willContinue = pa.willContinue
  }
}

extension NullValue {
  package func toAgentPlatform() -> AgentPlatform.PartialArg.NullValue {
    switch self {
    case .value: .value
    }
  }

  package init(fromAgentPlatform nv: AgentPlatform.PartialArg.NullValue) {
    switch nv {
    case .value: self = .value
    case .unrecognized: self = .value
    }
  }
}
