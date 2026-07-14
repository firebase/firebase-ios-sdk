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
  /// A single content block from the conversation history list.
  package struct HistoryContent: Codable, Sendable, Equatable, Hashable {
    /// List of consecutive messages from a given party.
    package let parts: [HistoryPart]?
    
    /// Optional. Indicates who generated these messages in the history. Generally this will be either 'user' or 'model'.
    package let role: String?
    
    /// Creates a new `HistoryContent`.
    package init(
      parts: [HistoryPart]? = nil,
      role: String? = nil
    ) {
      self.parts = parts
      self.role = role
    }
    enum CodingKeys: String, CodingKey {
      case parts = "parts"
      case role = "role"
    }
  }
}