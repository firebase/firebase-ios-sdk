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


extension GeminiDataModels {
  /// A collection of source attributions for a piece of content.
  /// 
  /// Variant:
  /// A collection of citations that apply to a piece of generated content.
  package struct CitationMetadata: Codable, Sendable, Equatable, Hashable {
    /// Output only. A list of citations for the content.
    /// 
    /// > Important: `citations` is only available in the Gemini Enterprise Agent Platform.
    package let citations: [Citation]?
    
    /// Citations to sources for a specific response.
    /// 
    /// > Important: `citationSources` is only available in the Gemini Developer API.
    package let citationSources: [CitationSource]?
    
    /// Creates a new `CitationMetadata`.
    package init(
      citations: [Citation]? = nil,
      citationSources: [CitationSource]? = nil
    ) {
      self.citations = citations
      self.citationSources = citationSources
    }
    enum CodingKeys: String, CodingKey {
      case citations = "citations"
      case citationSources = "citationSources"
    }
  }
}