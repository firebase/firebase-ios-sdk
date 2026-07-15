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
  /// An internal data model for `Content`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaContent`
  /// 
  /// The base structured datatype containing multi-part content of a message.
  /// 
  /// A `Content` includes a `role` field designating the producer of the `Content`
  /// and a `parts` field containing multi-part data that contains the content of
  /// the message turn.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1Content`
  /// 
  /// The structured data content of a message.
  /// 
  /// A Content message contains a `role`
  /// field, which indicates the producer of the content, and a `parts` field,
  /// which contains the multi-part data of the message.
  package struct Content: Codable, Sendable, Equatable, Hashable {
    /// Ordered `Parts` that constitute a single message. Parts may have different
    /// 
    /// ### Gemini Developer API
    /// 
    /// Ordered `Parts` that constitute a single message. Parts may have different
    /// MIME types.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. A list of Part objects
    /// that make up a single message. Parts of a message can have different MIME
    /// types.
    /// 
    /// A Content message must have at
    /// least one Part.
    package let parts: [Part]?
    
    /// Optional. The producer of the content. Must be either 'user' or 'model'.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The producer of the content. Must be either 'user' or 'model'.
    /// 
    /// Useful to set for multi-turn conversations, otherwise can be left blank
    /// or unset.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The producer of the content. Must be either 'user' or 'model'.
    /// 
    /// If not set, the service will default to 'user'.
    package let role: String?
    

    /// Creates a new `Content`.
    ///
    /// - Parameters:
    ///   - parts: Ordered `Parts` that constitute a single message. Parts may have different (behavior varies by backend). For more details, see ``parts``.
    ///   - role: Optional. The producer of the content. Must be either 'user' or 'model'. (behavior varies by backend). For more details, see ``role``.
    package init(
      parts: [Part]? = nil,
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