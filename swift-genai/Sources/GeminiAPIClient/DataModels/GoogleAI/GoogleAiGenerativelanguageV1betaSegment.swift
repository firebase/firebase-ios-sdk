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
  /// Segment of the content.
  package struct GoogleAiGenerativelanguageV1betaSegment: Codable, Sendable, Equatable, Hashable {
    /// End index in the given Part, measured in bytes. Offset from the start of the Part, exclusive, starting at zero.
    package var endIndex: Int?
    
    /// The index of a Part object within its parent Content object.
    package var partIndex: Int?
    
    /// Start index in the given Part, measured in bytes. Offset from the start of the Part, inclusive, starting at zero.
    package var startIndex: Int?
    
    /// The text corresponding to the segment from the response.
    package var text: String?
    
    /// Creates a new `GoogleAiGenerativelanguageV1betaSegment`.
    package init(
      endIndex: Int? = nil,
      partIndex: Int? = nil,
      startIndex: Int? = nil,
      text: String? = nil
    ) {
      self.endIndex = endIndex
      self.partIndex = partIndex
      self.startIndex = startIndex
      self.text = text
    }
    enum CodingKeys: String, CodingKey {
      case endIndex = "endIndex"
      case partIndex = "partIndex"
      case startIndex = "startIndex"
      case text = "text"
    }
  }
}