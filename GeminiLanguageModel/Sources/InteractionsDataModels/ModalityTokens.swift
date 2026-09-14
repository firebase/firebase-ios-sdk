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

/// The token count for a single response modality.
package struct ModalityTokens: Codable, Sendable, Equatable, Hashable {

  /// The modality associated with the token count.
  package let modality: ResponseModality?

  /// Number of tokens for the modality.
  package let tokens: Int?

  /// Creates a new `ModalityTokens`.
  ///
  /// - Parameters:
  ///   - modality: The modality associated with the token count.
  ///   - tokens: Number of tokens for the modality.
  package init(
    modality: ResponseModality? = nil,
    tokens: Int? = nil
  ) {
    self.modality = modality
    self.tokens = tokens
  }
  enum CodingKeys: String, CodingKey {
    case modality = "modality"
    case tokens = "tokens"
  }
}
