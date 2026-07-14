// Copyright 2025 Google LLC
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

/// Metadata related to the ``Tool/urlContext()`` tool.
public struct URLContextMetadata: Sendable, Hashable {
  /// List of URL metadata used to provide context to the Gemini model.
  public let urlMetadata: [URLMetadata]
}

// MARK: - Mappings

import GoogleAIDataModels
import AgentPlatformDataModels

extension URLContextMetadata {
  package func toGoogleAI() -> GoogleAI.UrlContextMetadata {
    GoogleAI.UrlContextMetadata(
      urlMetadata: urlMetadata.map { $0.toGoogleAI() }
    )
  }

  package func toAgentPlatform() -> AgentPlatform.UrlContextMetadata {
    AgentPlatform.UrlContextMetadata(
      urlMetadata: urlMetadata.map { $0.toAgentPlatform() }
    )
  }

  package init(fromGoogleAI metadata: GoogleAI.UrlContextMetadata) {
    self.urlMetadata = metadata.urlMetadata?.map { URLMetadata(fromGoogleAI: $0) } ?? []
  }

  package init(fromAgentPlatform metadata: AgentPlatform.UrlContextMetadata) {
    self.urlMetadata = metadata.urlMetadata?.map { URLMetadata(fromAgentPlatform: $0) } ?? []
  }
}
