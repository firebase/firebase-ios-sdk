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
  /// The base structured datatype containing multi-part content of a message. A `Content` includes a `role` field designating the producer of the `Content` and a `parts` field containing multi-part data that contains the content of the message turn.
  public struct Content: Codable, Sendable, Equatable, Hashable {
    /// Ordered `Parts` that constitute a single message. Parts may have different MIME types.
    public var parts: [Part]?
    
    /// Optional. The producer of the content. Must be either 'user' or 'model'. Useful to set for multi-turn conversations, otherwise can be left blank or unset.
    public var role: String?
    
    /// Creates a new `Content`.
    public init(
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