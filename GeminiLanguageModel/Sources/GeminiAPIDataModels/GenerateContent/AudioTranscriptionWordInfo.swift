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

/// Information about a single recognized word.
package struct AudioTranscriptionWordInfo: Codable, Sendable, Equatable, Hashable, Buildable {
  /// End offset in time of the word relative to the start of the audio.
  package var endOffset: String?

  /// Start offset in time of the word relative to the start of the audio.
  package var startOffset: String?

  /// Required. Transcript of the word.
  package var word: String?

  /// Initializes a new `AudioTranscriptionWordInfo`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case endOffset
    case startOffset
    case word
  }
}
