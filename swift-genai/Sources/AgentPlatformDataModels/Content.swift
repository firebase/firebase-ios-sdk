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


extension AgentPlatform {
  /// The structured data content of a message. A Content message contains a `role` field, which indicates the producer of the content, and a `parts` field, which contains the multi-part data of the message.
  package struct Content: Codable, Sendable, Equatable, Hashable {
    /// Required. A list of Part objects that make up a single message. Parts of a message can have different MIME types. A Content message must have at least one Part.
    package var parts: [Part]?
    
    /// Optional. The producer of the content. Must be either 'user' or 'model'. If not set, the service will default to 'user'.
    package var role: String?
    
    /// Creates a new `Content`.
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