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




extension AgentPlatform {
  /// A citation for a piece of generatedcontent.
  package struct Citation: Codable, Sendable, Equatable, Hashable {
    /// Output only. The end index of the citation in the content.
    package var endIndex: Int?
    
    /// Output only. The license of the source of the citation.
    package var license: String?
    
    /// Output only. The publication date of the source of the citation.
    package var publicationDate: GoogleTypeDate?
    
    /// Output only. The start index of the citation in the content.
    package var startIndex: Int?
    
    /// Output only. The title of the source of the citation.
    package var title: String?
    
    /// Output only. The URI of the source of the citation.
    package var uri: String?
    
    /// Creates a new `Citation`.
    package init(
      endIndex: Int? = nil,
      license: String? = nil,
      publicationDate: GoogleTypeDate? = nil,
      startIndex: Int? = nil,
      title: String? = nil,
      uri: String? = nil
    ) {
      self.endIndex = endIndex
      self.license = license
      self.publicationDate = publicationDate
      self.startIndex = startIndex
      self.title = title
      self.uri = uri
    }
    enum CodingKeys: String, CodingKey {
      case endIndex = "endIndex"
      case license = "license"
      case publicationDate = "publicationDate"
      case startIndex = "startIndex"
      case title = "title"
      case uri = "uri"
    }
  }
}