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

/// A citation for a piece of generatedcontent.
package struct Citation: Codable, Sendable, Equatable, Hashable, Buildable {
  /// The end index of the citation in the content.
  package var endIndex: Int?

  /// The license of the source of the citation.
  package var license: String?

  /// The publication date of the source of the citation.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var publicationDate: CalendarDate?

  /// The start index of the citation in the content.
  package var startIndex: Int?

  /// The title of the source of the citation.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var title: String?

  /// The URI of the source of the citation.
  package var uri: String?

  /// Initializes a new `Citation`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case endIndex
    case license
    case publicationDate
    case startIndex
    case title
    case uri
  }
}
