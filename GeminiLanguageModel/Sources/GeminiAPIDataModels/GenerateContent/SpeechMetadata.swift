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

/// Structured Metadata Sub-Message for Part
package struct SpeechMetadata: Codable, Sendable, Equatable, Hashable, Buildable {
  /// Identifies which speaker is speaking this turn.
  package var speaker: String?

  /// Natural language description of the vocal style (e.g., "cheerful").
  package var style: String?

  /// Initializes a new `SpeechMetadata`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case speaker
    case style
  }
}
