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

/// Speech metadata for ``TextPart``.
public struct SpeechMetadata: Sendable, Equatable {
  /// Optional speaker name for multi-speaker synthesis.
  let speaker: String?

  /// Optional style instruction for the speech synthesis.
  let style: String?

  public init(speaker: String? = nil, style: String? = nil) {
    self.speaker = speaker
    self.style = style
  }
}

// MARK: - Codable Conformance

extension SpeechMetadata: Codable {}
