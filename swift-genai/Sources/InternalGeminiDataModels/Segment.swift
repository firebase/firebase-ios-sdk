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
  /// Segment of the content.
  /// 
  /// Variant:
  /// A segment of the content.
  package struct Segment: Codable, Sendable, Equatable, Hashable {
    /// The index of a Part object within its parent Content object.
    /// 
    /// Variant:
    /// Output only. The index of the `Part` object that this segment belongs to. This is useful for associating the segment with a specific part of the content.
    package let partIndex: Int?
    
    /// End index in the given Part, measured in bytes. Offset from the start of the Part, exclusive, starting at zero.
    /// 
    /// Variant:
    /// Output only. The end index of the segment in the `Part`, measured in bytes. This marks the end of the segment and is exclusive, meaning the segment includes content up to, but not including, the byte at this index.
    package let endIndex: Int?
    
    /// The text corresponding to the segment from the response.
    /// 
    /// Variant:
    /// Output only. The text of the segment.
    package let text: String?
    
    /// Start index in the given Part, measured in bytes. Offset from the start of the Part, inclusive, starting at zero.
    /// 
    /// Variant:
    /// Output only. The start index of the segment in the `Part`, measured in bytes. This marks the beginning of the segment and is inclusive, meaning the byte at this index is the first byte of the segment.
    package let startIndex: Int?
    
    /// Creates a new `Segment`.
    package init(
      partIndex: Int? = nil,
      endIndex: Int? = nil,
      text: String? = nil,
      startIndex: Int? = nil
    ) {
      self.partIndex = partIndex
      self.endIndex = endIndex
      self.text = text
      self.startIndex = startIndex
    }
    enum CodingKeys: String, CodingKey {
      case partIndex = "partIndex"
      case endIndex = "endIndex"
      case text = "text"
      case startIndex = "startIndex"
    }
  }
}