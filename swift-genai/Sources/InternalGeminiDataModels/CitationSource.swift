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
  /// An internal data model for `CitationSource`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaCitationSource`
  /// 
  /// A citation to a source for a portion of a specific response.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct CitationSource: Codable, Sendable, Equatable, Hashable {
    /// Optional. Start of segment of the response that is attributed to this source.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Start of segment of the response that is attributed to this source.
    /// 
    /// Index indicates the start of the segment, measured in bytes.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let startIndex: Int?
    
    /// Optional. End of the attributed segment, exclusive.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. End of the attributed segment, exclusive.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let endIndex: Int?
    
    /// Optional. URI that is attributed as a source for a portion of the text.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. URI that is attributed as a source for a portion of the text.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let uri: String?
    
    /// Optional. License for the GitHub project that is attributed as a source for segment.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. License for the GitHub project that is attributed as a source for segment.
    /// 
    /// License info is required for code citations.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let license: String?
    

    /// Creates a new `CitationSource`.
    ///
    /// - Parameters:
    ///   - startIndex: Optional. Start of segment of the response that is attributed to this source. (Gemini Developer API only). For more details, see ``startIndex``.
    ///   - endIndex: Optional. End of the attributed segment, exclusive. (Gemini Developer API only). For more details, see ``endIndex``.
    ///   - uri: Optional. URI that is attributed as a source for a portion of the text. (Gemini Developer API only). For more details, see ``uri``.
    ///   - license: Optional. License for the GitHub project that is attributed as a source for segment. (Gemini Developer API only). For more details, see ``license``.
    package init(
      startIndex: Int? = nil,
      endIndex: Int? = nil,
      uri: String? = nil,
      license: String? = nil
    ) {
      self.startIndex = startIndex
      self.endIndex = endIndex
      self.uri = uri
      self.license = license
    }
    enum CodingKeys: String, CodingKey {
      case startIndex = "startIndex"
      case endIndex = "endIndex"
      case uri = "uri"
      case license = "license"
    }
  }
}