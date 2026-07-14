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

/// Represents a function declaration.
public struct FunctionDeclaration: Codable, Sendable, Equatable, Hashable {
  public var name: String?
  public var description: String?
  package var parameters: InternalGoogleAIDataModels.GoogleAI.Schema?
  public var parametersJsonSchema: JSONValue?
  package var response: InternalGoogleAIDataModels.GoogleAI.Schema?
  public var responseJsonSchema: JSONValue?
  public var behavior: FunctionDeclarationBehavior?

  public init(
    name: String? = nil,
    description: String? = nil,
    parametersJsonSchema: JSONValue? = nil,
    responseJsonSchema: JSONValue? = nil,
    behavior: FunctionDeclarationBehavior? = nil
  ) {
    self.name = name
    self.description = description
    self.parameters = nil
    self.parametersJsonSchema = parametersJsonSchema
    self.response = nil
    self.responseJsonSchema = responseJsonSchema
    self.behavior = behavior
  }

  package init(
    name: String? = nil,
    description: String? = nil,
    parameters: InternalGoogleAIDataModels.GoogleAI.Schema? = nil,
    parametersJsonSchema: JSONValue? = nil,
    response: InternalGoogleAIDataModels.GoogleAI.Schema? = nil,
    responseJsonSchema: JSONValue? = nil,
    behavior: FunctionDeclarationBehavior? = nil
  ) {
    self.name = name
    self.description = description
    self.parameters = parameters
    self.parametersJsonSchema = parametersJsonSchema
    self.response = response
    self.responseJsonSchema = responseJsonSchema
    self.behavior = behavior
  }
}

public enum FunctionDeclarationBehavior: Codable, Sendable, Equatable, Hashable {
  case blocking
  case nonBlocking
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension FunctionDeclaration {
  package func toGoogleAI() -> GoogleAI.FunctionDeclaration {
    GoogleAI.FunctionDeclaration(
      behavior: behavior?.toGoogleAI(),
      description: description,
      name: name,
      parameters: parameters,
      parametersJsonSchema: parametersJsonSchema,
      response: response,
      responseJsonSchema: responseJsonSchema
    )
  }

  package init(fromGoogleAI fd: GoogleAI.FunctionDeclaration) {
    self.name = fd.name
    self.description = fd.description
    self.parameters = fd.parameters
    self.parametersJsonSchema = fd.parametersJsonSchema
    self.response = fd.response
    self.responseJsonSchema = fd.responseJsonSchema
    self.behavior = fd.behavior.map { FunctionDeclarationBehavior(fromGoogleAI: $0) }
  }
}

extension FunctionDeclarationBehavior {
  package func toGoogleAI() -> GoogleAI.FunctionDeclaration.Behavior {
    switch self {
    case .blocking: .blocking
    case .nonBlocking: .nonBlocking
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI behavior: GoogleAI.FunctionDeclaration.Behavior) {
    switch behavior {
    case .blocking: self = .blocking
    case .nonBlocking: self = .nonBlocking
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension FunctionDeclaration {
  package func toAgentPlatform() -> AgentPlatform.FunctionDeclaration {
    AgentPlatform.FunctionDeclaration(
      behavior: behavior?.toAgentPlatform(),
      description: description,
      name: name,
      parameters: parameters.flatMap { try? AgentPlatform.Schema(from: JSONDecoder().decode(GoogleAI.Schema.self, from: JSONEncoder().encode($0)) as! Decoder) },
      parametersJsonSchema: parametersJsonSchema,
      response: response.flatMap { try? AgentPlatform.Schema(from: JSONDecoder().decode(GoogleAI.Schema.self, from: JSONEncoder().encode($0)) as! Decoder) },
      responseJsonSchema: responseJsonSchema
    )
  }

  package init(fromAgentPlatform fd: AgentPlatform.FunctionDeclaration) {
    self.name = fd.name
    self.description = fd.description
    self.parameters = fd.parameters.flatMap { try? GoogleAI.Schema(from: JSONDecoder().decode(AgentPlatform.Schema.self, from: JSONEncoder().encode($0)) as! Decoder) }
    self.parametersJsonSchema = fd.parametersJsonSchema
    self.response = fd.response.flatMap { try? GoogleAI.Schema(from: JSONDecoder().decode(AgentPlatform.Schema.self, from: JSONEncoder().encode($0)) as! Decoder) }
    self.responseJsonSchema = fd.responseJsonSchema
    self.behavior = fd.behavior.map { FunctionDeclarationBehavior(fromAgentPlatform: $0) }
  }
}

extension FunctionDeclarationBehavior {
  package func toAgentPlatform() -> AgentPlatform.FunctionDeclaration.Behavior {
    switch self {
    case .blocking: .blocking
    case .nonBlocking: .nonBlocking
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform behavior: AgentPlatform.FunctionDeclaration.Behavior) {
    switch behavior {
    case .blocking: self = .blocking
    case .nonBlocking: self = .nonBlocking
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}
