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
  /// A collection of citations that apply to a piece of generated content.
  public struct CitationMetadata: Codable, Sendable, Equatable, Hashable {
    /// Output only. A list of citations for the content.
    public var citations: [Citation]?
    
    /// Creates a new `CitationMetadata`.
    public init(
      citations: [Citation]? = nil
    ) {
      self.citations = citations
    }
    enum CodingKeys: String, CodingKey {
      case citations = "citations"
    }
  }
}