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

/// A safety rating for a piece of content. The safety rating contains the harm category and the
/// harm probability level.
package struct SafetyRating: Codable, Sendable, Equatable, Hashable, Buildable {
  /// Indicates whether the content was blocked because of this rating.
  package var blocked: Bool?

  /// The harm category of this rating.
  package var category: HarmCategory?

  /// The overwritten threshold for the safety category of Gemini 2.0 image out. If minors are
  /// detected in the output image, the threshold of each safety category will be overwritten if
  /// user sets a lower threshold.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var overwrittenThreshold: OverwrittenThreshold?

  /// The probability of harm for this category.
  package var probability: Probability?

  /// The probability score of harm for this category.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var probabilityScore: Double?

  /// The severity of harm for this category.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var severity: Severity?

  /// The severity score of harm for this category.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var severityScore: Double?

  /// Initializes a new `SafetyRating`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case blocked
    case category
    case overwrittenThreshold
    case probability
    case probabilityScore
    case severity
    case severityScore
  }
}
