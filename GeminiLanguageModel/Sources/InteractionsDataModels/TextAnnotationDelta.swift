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

/// An internal data model for `TextAnnotationDelta`.
package struct TextAnnotationDelta: Codable, Sendable, Equatable, Hashable {

  /// Citation information for model-generated content.
  package let annotations: [Annotation]?

  package let type: String?

  /// Creates a new `TextAnnotationDelta`.
  ///
  /// - Parameters:
  ///   - annotations: Citation information for model-generated content.
  package init(
    annotations: [Annotation]? = nil
  ) {
    self.annotations = annotations
    self.type = "text_annotation_delta"
  }
  enum CodingKeys: String, CodingKey {
    case annotations = "annotations"
    case type = "type"
  }
}
