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
  /// A citation to a source for a portion of a specific response.
  /// 
  /// > Important: This type is only available in the Gemini Developer API.
  package struct CitationSource: Codable, Sendable, Equatable, Hashable {
    /// Optional. Start of segment of the response that is attributed to this source. Index indicates the start of the segment, measured in bytes.
    /// 
    /// > Important: `startIndex` is only available in the Gemini Developer API.
    package let startIndex: Int?
    
    /// Optional. URI that is attributed as a source for a portion of the text.
    /// 
    /// > Important: `uri` is only available in the Gemini Developer API.
    package let uri: String?
    
    /// Optional. End of the attributed segment, exclusive.
    /// 
    /// > Important: `endIndex` is only available in the Gemini Developer API.
    package let endIndex: Int?
    
    /// Optional. License for the GitHub project that is attributed as a source for segment. License info is required for code citations.
    /// 
    /// > Important: `license` is only available in the Gemini Developer API.
    package let license: String?
    
    /// Creates a new `CitationSource`.
    package init(
      startIndex: Int? = nil,
      uri: String? = nil,
      endIndex: Int? = nil,
      license: String? = nil
    ) {
      self.startIndex = startIndex
      self.uri = uri
      self.endIndex = endIndex
      self.license = license
    }
    enum CodingKeys: String, CodingKey {
      case startIndex = "startIndex"
      case uri = "uri"
      case endIndex = "endIndex"
      case license = "license"
    }
  }
}