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


extension GoogleAI {
  /// A citation to a source for a portion of a specific response.
  public struct CitationSource: Codable, Sendable, Equatable, Hashable {
    /// Optional. End of the attributed segment, exclusive.
    public var endIndex: Int?
    
    /// Optional. License for the GitHub project that is attributed as a source for segment. License info is required for code citations.
    public var license: String?
    
    /// Optional. Start of segment of the response that is attributed to this source. Index indicates the start of the segment, measured in bytes.
    public var startIndex: Int?
    
    /// Optional. URI that is attributed as a source for a portion of the text.
    public var uri: String?
    
    /// Creates a new `CitationSource`.
    public init(
      endIndex: Int? = nil,
      license: String? = nil,
      startIndex: Int? = nil,
      uri: String? = nil
    ) {
      self.endIndex = endIndex
      self.license = license
      self.startIndex = startIndex
      self.uri = uri
    }
    enum CodingKeys: String, CodingKey {
      case endIndex = "endIndex"
      case license = "license"
      case startIndex = "startIndex"
      case uri = "uri"
    }
  }
}