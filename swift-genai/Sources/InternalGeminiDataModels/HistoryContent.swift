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
  /// An internal data model for `HistoryContent`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `HistoryContent`
  /// 
  /// A single content block from the conversation history list.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `HistoryContent`
  /// 
  /// A single content block from the conversation history list.
  package struct HistoryContent: Codable, Sendable, Equatable, Hashable {
    /// Optional. Indicates who generated these messages in the history. Generally this will
    /// be either 'user' or 'model'.
    package let role: String?
    
    /// List of consecutive messages from a given party.
    package let parts: [HistoryPart]?
    

    /// Creates a new `HistoryContent`.
    ///
    /// - Parameters:
    ///   - role: Optional. Indicates who generated these messages in the history. Generally this will
    ///   - parts: List of consecutive messages from a given party.
    package init(
      role: String? = nil,
      parts: [HistoryPart]? = nil
    ) {
      self.role = role
      self.parts = parts
    }
    enum CodingKeys: String, CodingKey {
      case role = "role"
      case parts = "parts"
    }
  }
}