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
package import GoogleAIDataModels
package import AgentPlatformDataModels

/// Represents a reference to file data.
public struct FileData: Codable, Sendable, Equatable, Hashable {
  public var fileUri: String?
  public var mimeType: String?
  /// - Note: Only supported on AgentPlatform backend.
  public var displayName: String?

  public init(fileUri: String? = nil, mimeType: String? = nil, displayName: String? = nil) {
    self.fileUri = fileUri
    self.mimeType = mimeType
    self.displayName = displayName
  }
}

// MARK: - GoogleAI Mappings

extension FileData {
  package func toGoogleAI() -> GoogleAI.FileData {
    GoogleAI.FileData(fileUri: fileUri, mimeType: mimeType)
  }

  package init(fromGoogleAI fd: GoogleAI.FileData) {
    self.fileUri = fd.fileUri
    self.mimeType = fd.mimeType
    self.displayName = nil
  }
}

// MARK: - AgentPlatform Mappings

extension FileData {
  package func toAgentPlatform() -> AgentPlatform.FileData {
    AgentPlatform.FileData(displayName: displayName, fileUri: fileUri, mimeType: mimeType)
  }

  package init(fromAgentPlatform fd: AgentPlatform.FileData) {
    self.fileUri = fd.fileUri
    self.mimeType = fd.mimeType
    self.displayName = fd.displayName
  }
}
