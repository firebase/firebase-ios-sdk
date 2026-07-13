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

extension GoogleAI {
  /// Represents token counting info for a single modality.
  package struct ModalityTokenCount: Codable, Sendable, Equatable, Hashable {
    /// The modality associated with this token count.
    package var modality: Modality?
    
    /// Number of tokens.
    package var tokenCount: Int?
    
    /// Creates a new `ModalityTokenCount`.
    package init(
      modality: Modality? = nil,
      tokenCount: Int? = nil
    ) {
      self.modality = modality
      self.tokenCount = tokenCount
    }
    enum CodingKeys: String, CodingKey {
      case modality = "modality"
      case tokenCount = "tokenCount"
    }
  }
}