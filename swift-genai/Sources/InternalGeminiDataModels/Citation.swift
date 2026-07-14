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
  /// A citation for a piece of generatedcontent.
  /// 
  /// > Important: This type is only available in the Gemini Enterprise Agent Platform.
  package struct Citation: Codable, Sendable, Equatable, Hashable {
    /// Output only. The URI of the source of the citation.
    /// 
    /// > Important: `uri` is only available in the Gemini Enterprise Agent Platform.
    package let uri: String?
    
    /// Output only. The end index of the citation in the content.
    /// 
    /// > Important: `endIndex` is only available in the Gemini Enterprise Agent Platform.
    package let endIndex: Int?
    
    /// Output only. The license of the source of the citation.
    /// 
    /// > Important: `license` is only available in the Gemini Enterprise Agent Platform.
    package let license: String?
    
    /// Output only. The publication date of the source of the citation.
    /// 
    /// > Important: `publicationDate` is only available in the Gemini Enterprise Agent Platform.
    package let publicationDate: Date?
    
    /// Output only. The title of the source of the citation.
    /// 
    /// > Important: `title` is only available in the Gemini Enterprise Agent Platform.
    package let title: String?
    
    /// Output only. The start index of the citation in the content.
    /// 
    /// > Important: `startIndex` is only available in the Gemini Enterprise Agent Platform.
    package let startIndex: Int?
    
    /// Creates a new `Citation`.
    package init(
      uri: String? = nil,
      endIndex: Int? = nil,
      license: String? = nil,
      publicationDate: Date? = nil,
      title: String? = nil,
      startIndex: Int? = nil
    ) {
      self.uri = uri
      self.endIndex = endIndex
      self.license = license
      self.publicationDate = publicationDate
      self.title = title
      self.startIndex = startIndex
    }
    enum CodingKeys: String, CodingKey {
      case uri = "uri"
      case endIndex = "endIndex"
      case license = "license"
      case publicationDate = "publicationDate"
      case title = "title"
      case startIndex = "startIndex"
    }
  }
}