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
package import SharedDataModels
package import GoogleAIDataModels
package import AgentPlatformDataModels

/// The base structured datatype containing multi-part content of a message.
///
/// A `GeminiContent` includes a `role` field designating the producer of the content
/// and a `parts` field containing the multi-part content data.
public struct GeminiContent: Codable, Sendable, Equatable, Hashable {
  /// Ordered parts that constitute a single message.
  public var parts: [GeminiPart]?

  /// Optional. The producer of the content. Must be either 'user' or 'model'.
  public var role: String?

  /// Creates a new `GeminiContent`.
  public init(
    role: String? = nil,
    parts: [GeminiPart]? = nil
  ) {
    self.role = role
    self.parts = parts
  }
}

// MARK: - GoogleAI Mappings
extension GeminiContent {
  package func toGoogleAI() -> GoogleAI.Content {
    GoogleAI.Content(
      parts: parts?.map { $0.toGoogleAI() },
      role: role
    )
  }

  package init(fromGoogleAI content: GoogleAI.Content) {
    self.role = content.role
    self.parts = content.parts?.map { GeminiPart(fromGoogleAI: $0) }
  }
}

// MARK: - AgentPlatform Mappings
extension GeminiContent {
  package func toAgentPlatform() -> AgentPlatform.Content {
    AgentPlatform.Content(
      parts: parts?.map { $0.toAgentPlatform() },
      role: role
    )
  }

  package init(fromAgentPlatform content: AgentPlatform.Content) {
    self.role = content.role
    self.parts = content.parts?.map { GeminiPart(fromAgentPlatform: $0) }
  }
}
