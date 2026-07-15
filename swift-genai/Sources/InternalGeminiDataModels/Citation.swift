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
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1Citation`
  /// 
  /// A citation for a piece of generatedcontent.
  package struct Citation: Codable, Sendable, Equatable, Hashable {
    /// Output only. The start index of the citation in the content.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The start index of the citation in the content.
    package let startIndex: Int?
    
    /// Output only. The end index of the citation in the content.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The end index of the citation in the content.
    package let endIndex: Int?
    
    /// Output only. The URI of the source of the citation.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The URI of the source of the citation.
    package let uri: String?
    
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
    
    /// Output only. The license of the source of the citation.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The license of the source of the citation.
    package let license: String?
    
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
    ///   - startIndex: Output only. The start index of the citation in the content. (Gemini Enterprise Agent Platform only). For more details, see ``startIndex``.
    ///   - endIndex: Output only. The end index of the citation in the content. (Gemini Enterprise Agent Platform only). For more details, see ``endIndex``.
    ///   - uri: Output only. The URI of the source of the citation. (Gemini Enterprise Agent Platform only). For more details, see ``uri``.
    ///   - title: Output only. The title of the source of the citation. (Gemini Enterprise Agent Platform only). For more details, see ``title``.
    ///   - license: Output only. The license of the source of the citation. (Gemini Enterprise Agent Platform only). For more details, see ``license``.
    ///   - publicationDate: Output only. The publication date of the source of the citation. (Gemini Enterprise Agent Platform only). For more details, see ``publicationDate``.
    package init(
      startIndex: Int? = nil,
      endIndex: Int? = nil,
      uri: String? = nil,
      title: String? = nil,
      license: String? = nil,
      publicationDate: Date? = nil
    ) {
      self.startIndex = startIndex
      self.endIndex = endIndex
      self.uri = uri
      self.title = title
      self.license = license
      self.publicationDate = publicationDate
    }
    enum CodingKeys: String, CodingKey {
      case startIndex = "startIndex"
      case endIndex = "endIndex"
      case uri = "uri"
      case title = "title"
      case license = "license"
      case publicationDate = "publicationDate"
    }
  }
}