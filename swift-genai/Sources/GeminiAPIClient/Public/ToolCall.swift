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
public import SharedDataModels
package import GoogleAIDataModels
package import AgentPlatformDataModels

/// Represents a tool call.
public struct ToolCall: Codable, Sendable, Equatable, Hashable {
  public var args: [String: JSONValue]?
  public var id: String?
  public var toolType: ToolType?

  public init(args: [String: JSONValue]? = nil, id: String? = nil, toolType: ToolType? = nil) {
    self.args = args
    self.id = id
    self.toolType = toolType
  }
}

public enum ToolType: Codable, Sendable, Equatable, Hashable {
  case googleSearchWeb
  case googleSearchImage
  case urlContext
  case googleMaps
  case fileSearch
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension ToolCall {
  package func toGoogleAI() -> GoogleAI.ToolCall {
    GoogleAI.ToolCall(args: args, id: id, toolType: toolType?.toGoogleAI())
  }

  package init(fromGoogleAI tc: GoogleAI.ToolCall) {
    self.args = tc.args
    self.id = tc.id
    self.toolType = tc.toolType.map { ToolType(fromGoogleAI: $0) }
  }
}

extension ToolType {
  package func toGoogleAI() -> GoogleAI.ToolCall.ToolType {
    switch self {
    case .googleSearchWeb: .googleSearchWeb
    case .googleSearchImage: .googleSearchImage
    case .urlContext: .urlContext
    case .googleMaps: .googleMaps
    case .fileSearch: .fileSearch
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI tt: GoogleAI.ToolCall.ToolType) {
    switch tt {
    case .googleSearchWeb: self = .googleSearchWeb
    case .googleSearchImage: self = .googleSearchImage
    case .urlContext: self = .urlContext
    case .googleMaps: self = .googleMaps
    case .fileSearch: self = .fileSearch
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}
