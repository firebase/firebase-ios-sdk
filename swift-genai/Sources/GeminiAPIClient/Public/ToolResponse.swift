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

/// Represents a response to a tool call.
public struct ToolResponse: Codable, Sendable, Equatable, Hashable {
  public var id: String?
  public var response: [String: JSONValue]?

  public init(id: String? = nil, response: [String: JSONValue]? = nil) {
    self.id = id
    self.response = response
  }
}

// MARK: - GoogleAI Mappings

extension ToolResponse {
  package func toGoogleAI() -> GoogleAI.ToolResponse {
    GoogleAI.ToolResponse(id: id, response: response)
  }

  package init(fromGoogleAI tr: GoogleAI.ToolResponse) {
    self.id = tr.id
    self.response = tr.response
  }
}
