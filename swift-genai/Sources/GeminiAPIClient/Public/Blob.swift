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

/// Represents a raw blob of data.
public struct Blob: Codable, Sendable, Equatable, Hashable {
  public var data: String?
  public var mimeType: String?
  /// - Note: Only supported on AgentPlatform backend.
  public var displayName: String?

  public init(data: String? = nil, mimeType: String? = nil, displayName: String? = nil) {
    self.data = data
    self.mimeType = mimeType
    self.displayName = displayName
  }
}

// MARK: - GoogleAI Mappings

extension Blob {
  package func toGoogleAI() -> GoogleAI.Blob {
    GoogleAI.Blob(data: data, mimeType: mimeType)
  }

  package init(fromGoogleAI blob: GoogleAI.Blob) {
    self.data = blob.data
    self.mimeType = blob.mimeType
    self.displayName = nil
  }
}

// MARK: - AgentPlatform Mappings

extension Blob {
  package func toAgentPlatform() -> AgentPlatform.Blob {
    AgentPlatform.Blob(data: data, displayName: displayName, mimeType: mimeType)
  }

  package init(fromAgentPlatform blob: AgentPlatform.Blob) {
    self.data = blob.data
    self.mimeType = blob.mimeType
    self.displayName = blob.displayName
  }
}
