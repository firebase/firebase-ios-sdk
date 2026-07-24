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

/// An internal data model for `ResponseFormatConfig`.
///
/// ### Gemini Developer API
///
/// Type: `GoogleAiGenerativelanguageV1betaResponseFormatConfig`
///
/// Configuration for the response output format. This is a flat object
/// where each optional sub-field configures a specific output modality.
///
/// ### Gemini Enterprise Agent Platform
///
/// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
package struct ResponseFormatConfig: Codable, Sendable, Equatable, Hashable {
  /// Optional. Text output format configuration.
  ///
  /// ### Gemini Developer API
  ///
  /// Optional. Text output format configuration.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package let text: TextResponseFormat?

  /// Optional. Audio output format configuration.
  ///
  /// ### Gemini Developer API
  ///
  /// Optional. Audio output format configuration.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package let audio: AudioResponseFormat?

  /// Optional. Image output format configuration.
  ///
  /// ### Gemini Developer API
  ///
  /// Optional. Image output format configuration.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package let image: ImageResponseFormat?

  /// Creates a new `ResponseFormatConfig`.
  ///
  /// - Parameters:
  ///   - text: Optional. Text output format configuration. (Gemini Developer API only). For more
  /// details, see ``text``.
  ///   - audio: Optional. Audio output format configuration. (Gemini Developer API only). For more
  /// details, see ``audio``.
  ///   - image: Optional. Image output format configuration. (Gemini Developer API only). For more
  /// details, see ``image``.
  package init(text: TextResponseFormat? = nil,
               audio: AudioResponseFormat? = nil,
               image: ImageResponseFormat? = nil) {
    self.text = text
    self.audio = audio
    self.image = image
  }

  enum CodingKeys: String, CodingKey {
    case text
    case audio
    case image
  }
}
