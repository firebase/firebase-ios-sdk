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

/// A segment of the content.
package struct Segment: Codable, Sendable, Equatable, Hashable, Buildable {
  /// The end index of the segment in the `Part`, measured in bytes. This marks the end of the
  /// segment and is exclusive, meaning the segment includes content up to, but not including, the
  /// byte at this index.
  package var endIndex: Int?

  /// The index of the `Part` object that this segment belongs to. This is useful for associating
  /// the segment with a specific part of the content.
  package var partIndex: Int?

  /// The start index of the segment in the `Part`, measured in bytes. This marks the beginning of
  /// the segment and is inclusive, meaning the byte at this index is the first byte of the segment.
  package var startIndex: Int?

  /// The text of the segment.
  package var text: String?

  /// Initializes a new `Segment`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case endIndex
    case partIndex
    case startIndex
    case text
  }
}
