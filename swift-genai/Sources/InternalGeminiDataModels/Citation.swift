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

public import Foundation




extension GeminiDataModels {
  /// An internal data model for `Citation`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaCitationSource`
  /// 
  /// A citation to a source for a portion of a specific response.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1Citation`
  /// 
  /// A citation for a piece of generatedcontent.
  package struct Citation: Codable, Sendable, Equatable, Hashable {
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
    /// Output only. The start index of the citation in the content.
    package let startIndex: Int?
    
    /// Optional. End of the attributed segment, exclusive.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. End of the attributed segment, exclusive.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The end index of the citation in the content.
    package let endIndex: Int?
    
    /// Optional. URI that is attributed as a source for a portion of the text.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. URI that is attributed as a source for a portion of the text.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The URI of the source of the citation.
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
    /// Output only. The license of the source of the citation.
    package let license: String?
    
    /// Output only. The title of the source of the citation.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The title of the source of the citation.
    package let title: String?
    
    /// Output only. The publication date of the source of the citation.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The publication date of the source of the citation.
    package let publicationDate: Date?
    

    /// Creates a new `Citation`.
    ///
    /// - Parameters:
    ///   - startIndex: Optional. Start of segment of the response that is attributed to this source. (behavior varies by backend). For more details, see ``startIndex``.
    ///   - endIndex: Optional. End of the attributed segment, exclusive. (behavior varies by backend). For more details, see ``endIndex``.
    ///   - uri: Optional. URI that is attributed as a source for a portion of the text. (behavior varies by backend). For more details, see ``uri``.
    ///   - license: Optional. License for the GitHub project that is attributed as a source for segment. (behavior varies by backend). For more details, see ``license``.
    ///   - title: Output only. The title of the source of the citation. (Gemini Enterprise Agent Platform only). For more details, see ``title``.
    ///   - publicationDate: Output only. The publication date of the source of the citation. (Gemini Enterprise Agent Platform only). For more details, see ``publicationDate``.
    package init(
      startIndex: Int? = nil,
      endIndex: Int? = nil,
      uri: String? = nil,
      license: String? = nil,
      title: String? = nil,
      publicationDate: Date? = nil
    ) {
      self.startIndex = startIndex
      self.endIndex = endIndex
      self.uri = uri
      self.license = license
      self.title = title
      self.publicationDate = publicationDate
    }
    enum CodingKeys: String, CodingKey {
      case startIndex = "startIndex"
      case endIndex = "endIndex"
      case uri = "uri"
      case license = "license"
      case title = "title"
      case publicationDate = "publicationDate"
    }
  }
}