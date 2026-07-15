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
  /// An internal data model for `Segment`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaSegment`
  /// 
  /// Segment of the content.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1Segment`
  /// 
  /// A segment of the content.
  package struct Segment: Codable, Sendable, Equatable, Hashable {
    /// The index of a Part object within its parent Content object.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The index of a Part object within its parent Content object.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The index of the `Part` object that this segment belongs to.
    /// This is useful for associating the segment with a specific part of the
    /// content.
    package let partIndex: Int?
    
    /// Start index in the given Part, measured in bytes. Offset from the start of
    /// 
    /// ### Gemini Developer API
    /// 
    /// Start index in the given Part, measured in bytes. Offset from the start of
    /// the Part, inclusive, starting at zero.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The start index of the segment in the `Part`, measured in
    /// bytes. This marks the beginning of the segment and is inclusive, meaning
    /// the byte at this index is the first byte of the segment.
    package let startIndex: Int?
    
    /// End index in the given Part, measured in bytes. Offset from the start of
    /// 
    /// ### Gemini Developer API
    /// 
    /// End index in the given Part, measured in bytes. Offset from the start of
    /// the Part, exclusive, starting at zero.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The end index of the segment in the `Part`, measured in
    /// bytes. This marks the end of the segment and is exclusive, meaning the
    /// segment includes content up to, but not including, the byte at this
    /// index.
    package let endIndex: Int?
    
    /// The text corresponding to the segment from the response.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The text corresponding to the segment from the response.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The text of the segment.
    package let text: String?
    

    /// Creates a new `Segment`.
    ///
    /// - Parameters:
    ///   - partIndex: The index of a Part object within its parent Content object. (behavior varies by backend). For more details, see ``partIndex``.
    ///   - startIndex: Start index in the given Part, measured in bytes. Offset from the start of (behavior varies by backend). For more details, see ``startIndex``.
    ///   - endIndex: End index in the given Part, measured in bytes. Offset from the start of (behavior varies by backend). For more details, see ``endIndex``.
    ///   - text: The text corresponding to the segment from the response. (behavior varies by backend). For more details, see ``text``.
    package init(
      partIndex: Int? = nil,
      startIndex: Int? = nil,
      endIndex: Int? = nil,
      text: String? = nil
    ) {
      self.partIndex = partIndex
      self.startIndex = startIndex
      self.endIndex = endIndex
      self.text = text
    }
    enum CodingKeys: String, CodingKey {
      case partIndex = "partIndex"
      case startIndex = "startIndex"
      case endIndex = "endIndex"
      case text = "text"
    }
  }
}