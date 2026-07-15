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
  /// An internal data model for `CitationMetadata`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaCitationMetadata`
  /// 
  /// A collection of source attributions for a piece of content.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1CitationMetadata`
  /// 
  /// A collection of citations that apply to a piece of generated content.
  package struct CitationMetadata: Codable, Sendable, Equatable, Hashable {
    /// Citations to sources for a specific response.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Citations to sources for a specific response.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let citationSources: [CitationSource]?
    
    /// Output only. A list of citations for the content.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A list of citations for the content.
    package let citations: [Citation]?
    

    /// Creates a new `CitationMetadata`.
    ///
    /// - Parameters:
    ///   - citationSources: Citations to sources for a specific response. (Gemini Developer API only). For more details, see ``citationSources``.
    ///   - citations: Output only. A list of citations for the content. (Gemini Enterprise Agent Platform only). For more details, see ``citations``.
    package init(
      citationSources: [CitationSource]? = nil,
      citations: [Citation]? = nil
    ) {
      self.citationSources = citationSources
      self.citations = citations
    }
    enum CodingKeys: String, CodingKey {
      case citationSources = "citationSources"
      case citations = "citations"
    }
  }
}